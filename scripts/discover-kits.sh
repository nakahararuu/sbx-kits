#!/usr/bin/env bash
# Print every kit in the repository, one directory name per line, sorted.
#
# A kit is a directory holding a v3 descriptor named after it
# (<kit>/<kit>.yaml) whose first line is the kit frontend's syntax directive.
# A leftover v2 spec.yaml, a <kit>/<kit>.yaml without that directive, or a
# directory name that cannot be an image repository name is reported as a
# failure instead of being silently skipped (otherwise CI would pass without
# building or publishing that kit).
#
# Exit codes: 0 listed · 1 layout refused.

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$REPO_ROOT"

failed=0

if stale=$(find . -mindepth 2 -maxdepth 2 -name 'spec.yaml' -not -path './.claude/*' | grep .); then
  echo "error: v2 spec.yaml found (migrate to <kit>/<kit>.yaml, kit-spec v3): $stale" >&2
  failed=1
fi

kits=()
for f in */*.yaml; do
  [ -e "$f" ] || continue
  kit=${f%%/*}
  [ "$f" = "$kit/$kit.yaml" ] || continue
  if ! head -1 "$f" | grep -q '^# syntax=docker/sandbox-kit:3'; then
    echo "error: kit descriptor without '# syntax=docker/sandbox-kit:3' on its first line: $f" >&2
    failed=1
    continue
  fi
  # The directory name becomes the last path component of the published image
  # reference, so it has to be a valid OCI repository name component.
  if ! [[ "$kit" =~ ^[a-z0-9]+([._-][a-z0-9]+)*$ ]]; then
    echo "error: kit directory '$kit' is not a valid image name (lowercase letters, digits, '.', '_', '-')" >&2
    failed=1
    continue
  fi
  kits+=("$kit")
done

[ "$failed" -eq 0 ] || exit 1

if [ "${#kits[@]}" -gt 0 ]; then
  printf '%s\n' "${kits[@]}" | sort
fi
