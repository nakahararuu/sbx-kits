#!/usr/bin/env bash
# Regenerate every kit's settings.json / settings.install.json from its kit.json.
#
# kit.json is the single source of truth for domain allowlists; the two
# settings files are derived artifacts, checked in so they can be copied
# without cloning this repo. scripts/test.sh fails if they drift.
#
#   ./scripts/gen-settings.sh          # write
#   ./scripts/gen-settings.sh --check  # exit 1 if the checked-in files differ

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

command -v jq >/dev/null 2>&1 || { echo "error: jq is required" >&2; exit 1; }

status=0

emit() {
  local target="$1" generated="$2"
  if [ "$CHECK" -eq 1 ]; then
    if [ ! -f "$target" ] || ! printf '%s\n' "$generated" | diff -q - "$target" >/dev/null; then
      echo "out of date: ${target#"$ROOT"/} (run ./scripts/gen-settings.sh)" >&2
      status=1
    fi
  else
    printf '%s\n' "$generated" > "$target"
    echo "wrote ${target#"$ROOT"/}"
  fi
}

for kit_json in "$ROOT"/kits/*/kit.json; do
  kit_dir="$(dirname "$kit_json")"

  emit "$kit_dir/settings.json" "$(
    jq -S '{ sandbox: { network: { allowedDomains: .network.datadog.allowedDomains } } }' "$kit_json"
  )"

  emit "$kit_dir/settings.install.json" "$(
    jq -S '{
      sandbox: {
        network: {
          allowedDomains: (.network.datadog.allowedDomains + .network.toolchain.allowedDomains)
        }
      }
    }' "$kit_json"
  )"
done

exit "$status"
