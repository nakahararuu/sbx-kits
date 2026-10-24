#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"
file_path="$(echo "$input" | jq -r '.tool_input.file_path // .tool_response.filePath // empty')"

if [[ -z "$file_path" ]]; then
  exit 0
fi

# A kit is a directory <kit>/ holding its descriptor <kit>/<kit>.yaml. Any file
# in that directory can change the build (descriptor, <kit>.dockerfile recipe,
# <kit>-context.md, files/), so validate whenever the edited file sits under a
# kit directory.
dir="$(dirname "$file_path")"
kit_dir=""
while [[ "$dir" != "/" && "$dir" != "." ]]; do
  if [[ -f "$dir/$(basename "$dir").yaml" ]]; then
    kit_dir="$dir"
    break
  fi
  dir="$(dirname "$dir")"
done

if [[ -z "$kit_dir" ]]; then
  exit 0
fi

kit="$(basename "$kit_dir")"
descriptor="$kit_dir/$kit.yaml"

# CI discovers kits by this exact first line and fails on a descriptor without
# it, so hold the hook to the same rule.
if ! head -1 "$descriptor" | grep -qx '# syntax=docker/sandbox-kit:3'; then
  echo "$descriptor: first line must be exactly '# syntax=docker/sandbox-kit:3' (see .claude/rules/kit-spec.md)" >&2
  exit 2
fi

if ! command -v docker >/dev/null 2>&1 || ! docker buildx version >/dev/null 2>&1; then
  echo "docker buildx not found — skipping validation of $kit_dir" >&2
  exit 0
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon not reachable — skipping validation of $kit_dir" >&2
  exit 0
fi

# `sbx kit validate` rejects v3 source kits; building with the kit frontend is
# the validation path (strict decoding names the bad field and line).
set +e
output="$(docker buildx build "$kit_dir" -f "$descriptor" --output type=cacheonly --progress=plain 2>&1)"
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo "docker buildx build $kit_dir -f $descriptor --output type=cacheonly" >&2
  tail -n 30 <<< "$output" >&2
  exit 2
fi

exit 0
