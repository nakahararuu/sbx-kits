#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"
file_path="$(echo "$input" | jq -r '.tool_input.file_path // .tool_response.filePath // empty')"

if [[ -z "$file_path" ]]; then
  exit 0
fi

# A kit-spec v3 kit is a directory <kit>/ holding its descriptor <kit>/<kit>.yaml
# (first line `# syntax=docker/sandbox-kit:3`). Any file in that directory can
# change the build (descriptor, <kit>.dockerfile recipe, <kit>-context.md, files/),
# so validate whenever the edited file sits under a kit directory.
dir="$(dirname "$file_path")"
kit_dir=""
while [[ "$dir" != "/" && "$dir" != "." ]]; do
  descriptor="$dir/$(basename "$dir").yaml"
  if [[ -f "$descriptor" ]] && head -1 "$descriptor" | grep -q '^# syntax=docker/sandbox-kit:3'; then
    kit_dir="$dir"
    break
  fi
  dir="$(dirname "$dir")"
done

if [[ -z "$kit_dir" ]]; then
  if [[ "$(basename "$file_path")" == "spec.yaml" ]]; then
    echo "$file_path is a kit-spec v2 file. Kits in this repo are v3: write <kit>/<kit>.yaml instead (see .claude/rules/kit-spec.md)" >&2
    exit 2
  fi
  exit 0
fi

if ! command -v docker >/dev/null 2>&1 || ! docker buildx version >/dev/null 2>&1; then
  echo "docker buildx not found — skipping validation of $kit_dir" >&2
  exit 0
fi

# `sbx kit validate` rejects v3 source kits; building with the kit frontend is
# the v3 validation path (strict decoding names the bad field and line).
kit="$(basename "$kit_dir")"
set +e
output="$(docker buildx build "$kit_dir" -f "$kit_dir/$kit.yaml" --output type=cacheonly --progress=plain 2>&1)"
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo "docker buildx build $kit_dir -f $kit_dir/$kit.yaml --output type=cacheonly" >&2
  tail -n 30 <<< "$output" >&2
  exit 2
fi

exit 0
