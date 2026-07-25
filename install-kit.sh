#!/usr/bin/env bash
# Install one or more sbx kits.
#
#   ./install-kit.sh --list
#   ./install-kit.sh datadog
#   ./install-kit.sh datadog -- --groups core,node --dry-run
#
# Everything after `--` is passed straight through to the kit's own install.sh.

set -euo pipefail

SBX_KITS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SBX_KITS_ROOT
# shellcheck source=lib/common.sh
. "$SBX_KITS_ROOT/lib/common.sh"

list_kits() {
  local kit_json name description
  for kit_json in "$SBX_KITS_ROOT"/kits/*/kit.json; do
    [ -e "$kit_json" ] || continue
    name="$(basename "$(dirname "$kit_json")")"
    if have jq; then
      description="$(jq -r '.description // ""' "$kit_json")"
    else
      description=""
    fi
    printf '  %-12s %s\n' "$name" "$description"
  done
}

usage() {
  cat <<EOF
Usage: install-kit.sh [--list] <kit> [<kit>...] [-- <kit args>]

Available kits:
$(list_kits)

Options:
  --list      List available kits and exit.
  -h, --help  Show this help.
EOF
}

kits=()
kit_args=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --list)    list_kits; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    --)        shift; kit_args=("$@"); break ;;
    -*)        die "unknown option: $1 (kit-specific flags go after --)" ;;
    *)         kits+=("$1"); shift ;;
  esac
done

[ "${#kits[@]}" -gt 0 ] || { usage >&2; exit 2; }

for kit in "${kits[@]}"; do
  installer="$SBX_KITS_ROOT/kits/$kit/install.sh"
  [ -x "$installer" ] || die "no such kit: $kit (try --list)"
  if [ "${#kit_args[@]}" -gt 0 ]; then
    "$installer" "${kit_args[@]}"
  else
    "$installer"
  fi
done
