#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"
file_path="$(echo "$input" | jq -r '.tool_input.file_path // .tool_response.filePath // empty')"

if [[ -z "$file_path" || "$(basename "$file_path")" != "spec.yaml" ]]; then
  exit 0
fi

if ! command -v sbx >/dev/null 2>&1; then
  echo "sbx CLI not found on PATH — skipping validation of $file_path (install the sbx-kit-dev kit, or sbx manually)" >&2
  exit 0
fi

kit_dir="$(dirname "$file_path")"
set +e
output="$(sbx kit validate "$kit_dir" 2>&1)"
status=$?
set -e

if [[ $status -ne 0 ]] || grep -q '^WARN:' <<< "$output"; then
  echo "sbx kit validate $kit_dir" >&2
  echo "$output" >&2
  exit 2
fi

exit 0
