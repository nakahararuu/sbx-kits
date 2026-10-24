#!/usr/bin/env bash
# Build one kit with the kit frontend and publish it as an OCI image.
#
# Usage:
#   scripts/publish-kit.sh <kit>
#
#   DRY_RUN=1 scripts/publish-kit.sh chrome-devtools-host   # build it, push nothing
#   scripts/publish-kit.sh chrome-devtools-host             # build and push
#
# Environment:
#   IMAGE_PREFIX  default ghcr.io/nakahararuu/sbx-kits — published as <prefix>/<kit>
#   PLATFORMS     default linux/amd64,linux/arm64
#   GIT_SHA       default `git rev-parse HEAD` — for the immutable sha-<short> tag
#   BUILDER       optional — passed as --builder
#   DRY_RUN       set to any value — build with --output type=cacheonly, no push
#
# Tags: <version> (the descriptor's top-level `version:`), latest, and
# sha-<12 hex> of the commit. `<version>` and `latest` move on every publish;
# pin the sha tag or a digest when the bytes must hold still.
#
# A v3 kit IS an image: the kit frontend named on the descriptor's first line
# validates the descriptor during the build and stores it in the image index's
# annotations, so `docker buildx build --push` is the whole publish. Pushing
# needs a BuildKit that can export OCI images (the docker-container driver, as
# set up by docker/setup-buildx-action, or the containerd image store); the
# plain docker driver fails with "OCI exporter is not supported for the docker
# driver", which is exactly why kits are published from CI rather than built
# from source on each host.
#
# Emits `ref=`, `version=`, `tags=` and `pushed=` on stdout so CI can redirect
# into $GITHUB_OUTPUT; everything else goes to stderr. When GITHUB_STEP_SUMMARY
# is set, a summary is appended there too.
#
# Exit codes: 0 published (or dry run) · 1 refused or failed · 2 usage error.

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 <kit>" >&2
  exit 2
fi

kit=$1

IMAGE_PREFIX=${IMAGE_PREFIX:-ghcr.io/nakahararuu/sbx-kits}
PLATFORMS=${PLATFORMS:-linux/amd64,linux/arm64}
BUILDER=${BUILDER:-}
DRY_RUN=${DRY_RUN:-}

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
GIT_SHA=${GIT_SHA:-$(git -C "$REPO_ROOT" rev-parse HEAD)}

# Keep the KEY=VALUE stream on fd 3 and send all other stdout to stderr, so a
# chatty command can never write a stray line into $GITHUB_OUTPUT.
exec 3>&1 1>&2

die() { echo "error: $*"; exit 1; }
emit() { echo "$1=$2" >&3; }

descriptor="$REPO_ROOT/$kit/$kit.yaml"
[ -f "$descriptor" ] || die "no kit '$kit' at the repo root (expected $kit/$kit.yaml)"
grep -qxF "$kit" < <("$REPO_ROOT/scripts/discover-kits.sh") ||
  die "'$kit' is not a publishable kit — see scripts/discover-kits.sh"

# The top-level `version:` literal (column zero only; indented keys belong to
# capabilities). Comment stripped before quotes, so `"1.0.0"  # note` works.
version=$(awk '
  index($0, "version:") == 1 {
    sub(/^version:[[:space:]]*/, "")
    sub(/[[:space:]]+#.*$/, "")
    gsub(/^["'"'"']|["'"'"']$/, "")
    print
    exit
  }
' "$descriptor")
[ -n "$version" ] || die "$kit/$kit.yaml has no top-level version: — add one, e.g. version: \"1.0.0\""
[[ "$version" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]] ||
  die "$kit/$kit.yaml version '$version' cannot be used as an image tag"

ref="${IMAGE_PREFIX}/${kit}"
sha_tag="sha-${GIT_SHA:0:12}"
tags="${version},latest,${sha_tag}"

echo "kit        : ${kit}"
echo "version    : ${version}"
echo "reference  : ${ref}"
echo "tags       : ${tags}"
echo "platforms  : ${PLATFORMS}"

# All tags are arguments to ONE build, so they cannot end up describing
# different bytes.
args=(
  buildx build
  "$REPO_ROOT/$kit"
  -f "$descriptor"
  --platform "$PLATFORMS"
  --provenance=true
  -t "${ref}:${version}"
  -t "${ref}:latest"
  -t "${ref}:${sha_tag}"
)
if [ -n "$BUILDER" ]; then args+=(--builder "$BUILDER"); fi
if [ -n "$DRY_RUN" ]; then
  args+=(--output type=cacheonly)
else
  args+=(--push)
fi

echo ""
echo "==> docker ${args[*]}"
echo ""

docker "${args[@]}"

emit ref "$ref"
emit version "$version"
emit tags "$tags"
emit pushed "$([ -n "$DRY_RUN" ] && echo false || echo true)"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "## ${kit}"
    echo ""
    if [ -n "$DRY_RUN" ]; then
      echo "**Dry run — built, nothing published.** Would have published:"
    else
      echo "Published:"
    fi
    echo ""
    echo "- \`${ref}:${version}\`"
    echo "- \`${ref}:latest\`"
    echo "- \`${ref}:${sha_tag}\`"
    echo ""
    echo "Platforms: \`${PLATFORMS}\`."
  } >> "$GITHUB_STEP_SUMMARY"
fi
