#!/usr/bin/env bash
# Shared helpers for sbx kit installers.
#
# Source this from a kit's install.sh:
#   . "$SBX_KITS_ROOT/lib/common.sh"

set -euo pipefail

# ---------------------------------------------------------------- logging ---

if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
  _c_dim=$'\033[2m'; _c_red=$'\033[31m'; _c_yellow=$'\033[33m'
  _c_green=$'\033[32m'; _c_bold=$'\033[1m'; _c_off=$'\033[0m'
else
  _c_dim=''; _c_red=''; _c_yellow=''; _c_green=''; _c_bold=''; _c_off=''
fi

log()   { printf '%s\n' "${_c_dim}·${_c_off} $*" >&2; }
info()  { printf '%s\n' "${_c_bold}==>${_c_off} $*" >&2; }
warn()  { printf '%s\n' "${_c_yellow}warn:${_c_off} $*" >&2; }
ok()    { printf '%s\n' "${_c_green}ok:${_c_off} $*" >&2; }
die()   { printf '%s\n' "${_c_red}error:${_c_off} $*" >&2; exit 1; }

# --------------------------------------------------------------- platform ---

sbx_os() {
  case "$(uname -s)" in
    Linux)  printf 'linux' ;;
    Darwin) printf 'darwin' ;;
    *)      die "unsupported OS: $(uname -s)" ;;
  esac
}

# Normalised architecture. Callers map this to whatever each project names it.
sbx_arch() {
  case "$(uname -m)" in
    x86_64|amd64)  printf 'x86_64' ;;
    aarch64|arm64) printf 'arm64' ;;
    *)             die "unsupported architecture: $(uname -m)" ;;
  esac
}

have() { command -v "$1" >/dev/null 2>&1; }

# Run as root when we are not already, without assuming sudo exists.
sbx_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif have sudo; then
    sudo "$@"
  else
    return 1
  fi
}

# Install OS packages best-effort. Returns non-zero when no package manager is
# usable so callers can fall back to a tarball download.
sbx_pkg_install() {
  [ "$#" -gt 0 ] || return 0
  if have apt-get; then
    sbx_sudo env DEBIAN_FRONTEND=noninteractive apt-get update -qq || return 1
    sbx_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@" || return 1
  elif have dnf; then
    sbx_sudo dnf install -y "$@" || return 1
  elif have apk; then
    sbx_sudo apk add --no-cache "$@" || return 1
  elif have brew; then
    brew install "$@" || return 1
  else
    return 1
  fi
}

# --------------------------------------------------------------- download ---

# sbx_fetch <url> <dest-file>
sbx_fetch() {
  local url="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if have curl; then
    curl -fsSL --retry 3 --retry-delay 2 -o "$dest" "$url"
  elif have wget; then
    wget -q -O "$dest" "$url"
  else
    die "neither curl nor wget is available; cannot download $url"
  fi
}

# sbx_fetch_stdout <url>
sbx_fetch_stdout() {
  local url="$1"
  if have curl; then
    curl -fsSL --retry 3 --retry-delay 2 "$url"
  elif have wget; then
    wget -qO- "$url"
  else
    die "neither curl nor wget is available; cannot download $url"
  fi
}

# sbx_extract_bin <tarball> <binary-name> <dest-dir> <workdir>
# Pulls a single binary out of a .tar.gz / .zip regardless of how deeply the
# archive nests it, and installs it executable into dest-dir. workdir must be a
# caller-owned scratch directory.
sbx_extract_bin() {
  local archive="$1" binary="$2" dest_dir="$3" workdir="$4"
  local tmp found
  tmp="$workdir/extract.$$"
  rm -rf "$tmp"
  mkdir -p "$tmp"

  case "$archive" in
    *.tar.gz|*.tgz) tar -xzf "$archive" -C "$tmp" ;;
    *.zip)          have unzip || die "unzip is required to extract $archive"
                    unzip -qo "$archive" -d "$tmp" ;;
    *)              die "unknown archive format: $archive" ;;
  esac

  found="$(find "$tmp" -type f -name "$binary" -perm -u+x -print -quit)"
  [ -n "$found" ] || found="$(find "$tmp" -type f -name "$binary" -print -quit)"
  [ -n "$found" ] || die "$binary not found inside $archive"

  mkdir -p "$dest_dir"
  install -m 0755 "$found" "$dest_dir/$binary"
  rm -rf "$tmp"
}

# ------------------------------------------------------------------- misc ---

# sbx_version_ge <have> <want> — dotted numeric comparison, "20.19.0" style.
sbx_version_ge() {
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

# sbx_on_path <dir> — warn once if dir is not on PATH, and print the hint the
# user needs to make it permanent.
sbx_on_path() {
  local dir="$1"
  case ":$PATH:" in
    *":$dir:"*) return 0 ;;
  esac
  warn "$dir is not on your PATH. Add it with:"
  # shellcheck disable=SC2016  # $PATH is meant to stay literal in the hint
  printf '\n    export PATH="%s:$PATH"\n\n' "$dir" >&2
}
