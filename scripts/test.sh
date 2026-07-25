#!/usr/bin/env bash
# Repository checks: shell syntax, JSON validity, generated-file freshness, and
# a dry run of every kit installer.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail=0
check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf '  ok    %s\n' "$label"
  else
    printf '  FAIL  %s\n' "$label"
    "$@" >/dev/null || true
    fail=1
  fi
}

echo "shell syntax"
while IFS= read -r f; do
  check "$f" bash -n "$f"
done < <(find . -name '*.sh' -not -path './.git/*' | sort)

echo "executable bits"
while IFS= read -r f; do
  case "$f" in
    ./lib/*) continue ;;  # sourced, not executed
  esac
  check "$f" test -x "$f"
done < <(find . -name '*.sh' -not -path './.git/*' | sort)

echo "json validity"
if command -v jq >/dev/null 2>&1; then
  while IFS= read -r f; do
    check "$f" jq -e . "$f"
  done < <(find . -name '*.json' -not -path './.git/*' | sort)
else
  echo "  skip  jq not installed"
fi

echo "generated settings are in sync"
if command -v jq >/dev/null 2>&1; then
  check "scripts/gen-settings.sh --check" ./scripts/gen-settings.sh --check
else
  echo "  skip  jq not installed"
fi

echo "shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
  while IFS= read -r f; do
    check "$f" shellcheck -x "$f"
  done < <(find . -name '*.sh' -not -path './.git/*' | sort)
else
  echo "  skip  shellcheck not installed"
fi

echo "installer dry runs"
while IFS= read -r installer; do
  check "$installer --dry-run" "$installer" --dry-run
done < <(find kits -name install.sh | sort)

exit "$fail"
