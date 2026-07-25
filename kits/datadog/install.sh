#!/usr/bin/env bash
# Datadog sbx kit.
#
# Installs:
#   1. every skill in datadog-labs/agent-skills
#   2. the CLI tools those skills drive (pup, node, kubectl, helm, gh, ddtrace)
#   3. a Claude Code sandbox network policy allowing all Datadog domains
#
# Run `./install.sh --help` for options.

set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SBX_KITS_ROOT="${SBX_KITS_ROOT:-$(cd "$KIT_DIR/../.." && pwd)}"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh
. "$SBX_KITS_ROOT/lib/common.sh"

KIT_JSON="$KIT_DIR/kit.json"

SKILLS_REPO="https://github.com/datadog-labs/agent-skills.git"
SKILLS_REF="${SBX_DATADOG_SKILLS_REF:-main}"
SKILLS_DIR="${SBX_DATADOG_SKILLS_DIR:-$HOME/.claude/skills}"
PREFIX="${SBX_DATADOG_PREFIX:-$HOME/.local/bin}"
KIT_HOME="${SBX_DATADOG_HOME:-$HOME/.local/share/sbx-kits/datadog}"
SETTINGS_FILE="${SBX_DATADOG_SETTINGS:-$HOME/.claude/settings.json}"

# Pinned fallbacks, used only when the current version cannot be resolved.
PUP_VERSION="${PUP_VERSION:-}"
PUP_VERSION_FALLBACK="1.8.0"
NODE_VERSION="${NODE_VERSION:-22.14.0}"
NODE_MIN_VERSION="20.19.0"
KUBECTL_VERSION_FALLBACK="v1.31.4"
HELM_VERSION="${HELM_VERSION:-v3.16.3}"
GH_VERSION="${GH_VERSION:-2.63.2}"

TOOL_GROUPS="core,node,k8s,gh,python"
DO_SKILLS=1
DO_TOOLS=1
DO_SETTINGS=1
DO_MCP=0
INSTALL_DOMAINS=0
DRY_RUN=0

WORK=""
cleanup() { [ -n "$WORK" ] && rm -rf "$WORK"; }
trap cleanup EXIT

usage() {
  cat <<'EOF'
Usage: install.sh [options]

  --groups LIST       Tool groups to install (default: core,node,k8s,gh,python).
                      Available: core, node, k8s, gh, python. "core" is always
                      installed.
  --skills-only       Install skills only; skip tools and settings.
  --tools-only        Install tools only; skip skills and settings.
  --settings-only     Write the sandbox network policy only; skip skills and tools.
  --no-settings       Do not touch Claude Code settings.json.
  --with-mcp          Also register the Datadog MCP servers with `claude mcp add`.
                      Each server still needs an interactive OAuth login.
  --install-domains   Write the toolchain domains into settings.json as well as
                      the Datadog ones. Use when the installer itself has to run
                      inside a network-restricted sandbox.
  --ref REF           Git ref of datadog-labs/agent-skills (default: main).
  --skills-dir DIR    Skill install directory (default: ~/.claude/skills).
  --prefix DIR        Binary install directory (default: ~/.local/bin).
  --settings FILE     Settings file to merge into (default: ~/.claude/settings.json).
  --dry-run           Print what would happen; change nothing.
  -h, --help          Show this help.

Environment overrides: SBX_DATADOG_SKILLS_REF, SBX_DATADOG_SKILLS_DIR,
SBX_DATADOG_PREFIX, SBX_DATADOG_HOME, SBX_DATADOG_SETTINGS, PUP_VERSION,
NODE_VERSION, HELM_VERSION, GH_VERSION.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --groups)          TOOL_GROUPS="${2:?--groups needs a value}"; shift 2 ;;
    --skills-only)     DO_TOOLS=0; DO_SETTINGS=0; shift ;;
    --tools-only)      DO_SKILLS=0; DO_SETTINGS=0; shift ;;
    --settings-only)   DO_SKILLS=0; DO_TOOLS=0; shift ;;
    --no-settings)     DO_SETTINGS=0; shift ;;
    --with-mcp)        DO_MCP=1; shift ;;
    --install-domains) INSTALL_DOMAINS=1; shift ;;
    --ref)             SKILLS_REF="${2:?--ref needs a value}"; shift 2 ;;
    --skills-dir)      SKILLS_DIR="${2:?--skills-dir needs a value}"; shift 2 ;;
    --prefix)          PREFIX="${2:?--prefix needs a value}"; shift 2 ;;
    --settings)        SETTINGS_FILE="${2:?--settings needs a value}"; shift 2 ;;
    --dry-run)         DRY_RUN=1; shift ;;
    -h|--help)         usage; exit 0 ;;
    *)                 die "unknown option: $1 (try --help)" ;;
  esac
done

want_group() {
  [ "$1" = "core" ] && return 0
  case ",$TOOL_GROUPS," in *",$1,"*) return 0 ;; esac
  return 1
}

# =============================================================== bootstrap ===

bootstrap_base_tools() {
  local missing=()
  if ! have curl && ! have wget; then missing+=(curl); fi
  have git || missing+=(git)
  have jq  || missing+=(jq)
  have tar || missing+=(tar)

  if [ "${#missing[@]}" -eq 0 ]; then
    ok "base tools present"
    return 0
  fi

  info "installing base tools: ${missing[*]}"
  if [ "$DRY_RUN" -eq 1 ]; then
    log "would install ${missing[*]} via the system package manager"
    return 0
  fi
  if ! sbx_pkg_install ca-certificates "${missing[@]}"; then
    die "could not install ${missing[*]} automatically; install them and re-run"
  fi
}

# =================================================================== tools ===

resolve_pup_version() {
  if [ -n "$PUP_VERSION" ]; then printf '%s' "${PUP_VERSION#v}"; return; fi

  local v=""
  # GitHub API first, then the /releases/latest redirect, then the pin.
  if have jq; then
    v="$(sbx_fetch_stdout 'https://api.github.com/repos/datadog-labs/pup/releases/latest' 2>/dev/null \
          | jq -r '.tag_name // empty' 2>/dev/null || true)"
  fi
  if [ -z "$v" ] && have curl; then
    v="$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
          'https://github.com/datadog-labs/pup/releases/latest' 2>/dev/null \
          | sed -n 's|.*/tag/\(.*\)$|\1|p' || true)"
  fi
  v="${v#v}"
  if [ -z "$v" ]; then
    warn "could not resolve the latest pup release; falling back to $PUP_VERSION_FALLBACK"
    v="$PUP_VERSION_FALLBACK"
  fi
  printf '%s' "$v"
}

install_pup() {
  if have pup && pup --version >/dev/null 2>&1; then
    ok "pup already installed ($(pup --version 2>&1 | head -n1))"
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then log "would install pup into $PREFIX"; return 0; fi

  local version os arch tarball url
  version="$(resolve_pup_version)"
  case "$(sbx_os)" in
    linux)  os="Linux" ;;
    darwin) os="Darwin" ;;
  esac
  # pup's release assets use the uname spelling for both architectures.
  arch="$(sbx_arch)"
  tarball="pup_${version}_${os}_${arch}.tar.gz"
  url="https://github.com/datadog-labs/pup/releases/download/v${version}/${tarball}"

  info "installing pup ${version}"
  sbx_fetch "$url" "$WORK/$tarball"
  sbx_extract_bin "$WORK/$tarball" pup "$PREFIX" "$WORK"
  ok "pup -> $PREFIX/pup"
}

install_node() {
  if have node && sbx_version_ge "$(node --version | tr -d 'v')" "$NODE_MIN_VERSION"; then
    ok "node already installed ($(node --version))"
    return 0
  fi
  if have node; then
    warn "node $(node --version) is older than $NODE_MIN_VERSION; installing a newer one"
  fi
  if [ "$DRY_RUN" -eq 1 ]; then log "would install node $NODE_VERSION into $KIT_HOME/node"; return 0; fi

  local os arch tarball url dest bin
  case "$(sbx_os)" in linux) os="linux" ;; darwin) os="darwin" ;; esac
  case "$(sbx_arch)" in x86_64) arch="x64" ;; arm64) arch="arm64" ;; esac
  tarball="node-v${NODE_VERSION}-${os}-${arch}.tar.gz"
  url="https://nodejs.org/dist/v${NODE_VERSION}/${tarball}"
  dest="$KIT_HOME/node"

  info "installing node ${NODE_VERSION}"
  sbx_fetch "$url" "$WORK/$tarball"
  rm -rf "$dest"
  mkdir -p "$dest"
  tar -xzf "$WORK/$tarball" -C "$dest" --strip-components=1

  mkdir -p "$PREFIX"
  for bin in node npm npx; do
    ln -sf "$dest/bin/$bin" "$PREFIX/$bin"
  done
  ok "node/npm/npx -> $PREFIX"
}

install_kubectl() {
  if have kubectl; then ok "kubectl already installed"; return 0; fi
  if [ "$DRY_RUN" -eq 1 ]; then log "would install kubectl into $PREFIX"; return 0; fi

  local os arch version
  case "$(sbx_os)" in linux) os="linux" ;; darwin) os="darwin" ;; esac
  case "$(sbx_arch)" in x86_64) arch="amd64" ;; arm64) arch="arm64" ;; esac
  version="$(sbx_fetch_stdout https://dl.k8s.io/release/stable.txt 2>/dev/null || true)"
  [ -n "$version" ] || version="$KUBECTL_VERSION_FALLBACK"

  info "installing kubectl ${version}"
  sbx_fetch "https://dl.k8s.io/release/${version}/bin/${os}/${arch}/kubectl" "$WORK/kubectl"
  mkdir -p "$PREFIX"
  install -m 0755 "$WORK/kubectl" "$PREFIX/kubectl"
  ok "kubectl -> $PREFIX/kubectl"
}

install_helm() {
  if have helm; then ok "helm already installed"; return 0; fi
  if [ "$DRY_RUN" -eq 1 ]; then log "would install helm into $PREFIX"; return 0; fi

  local os arch tarball
  case "$(sbx_os)" in linux) os="linux" ;; darwin) os="darwin" ;; esac
  case "$(sbx_arch)" in x86_64) arch="amd64" ;; arm64) arch="arm64" ;; esac
  tarball="helm-${HELM_VERSION}-${os}-${arch}.tar.gz"

  info "installing helm ${HELM_VERSION}"
  sbx_fetch "https://get.helm.sh/${tarball}" "$WORK/$tarball"
  sbx_extract_bin "$WORK/$tarball" helm "$PREFIX" "$WORK"
  ok "helm -> $PREFIX/helm"
}

install_gh() {
  if have gh; then ok "gh already installed"; return 0; fi
  if [ "$DRY_RUN" -eq 1 ]; then log "would install gh into $PREFIX"; return 0; fi

  local os arch tarball
  case "$(sbx_os)" in linux) os="linux" ;; darwin) os="macOS" ;; esac
  case "$(sbx_arch)" in x86_64) arch="amd64" ;; arm64) arch="arm64" ;; esac
  tarball="gh_${GH_VERSION}_${os}_${arch}.tar.gz"

  info "installing gh ${GH_VERSION}"
  sbx_fetch "https://github.com/cli/cli/releases/download/v${GH_VERSION}/${tarball}" "$WORK/$tarball"
  sbx_extract_bin "$WORK/$tarball" gh "$PREFIX" "$WORK"
  ok "gh -> $PREFIX/gh"
}

install_python_deps() {
  if ! have python3; then
    info "installing python3"
    if [ "$DRY_RUN" -eq 1 ]; then
      log "would install python3 via the system package manager"
    elif ! sbx_pkg_install python3 python3-venv python3-pip; then
      warn "could not install python3; skipping the agent-observability Python dependencies"
      return 0
    fi
  fi
  if [ "$DRY_RUN" -eq 1 ]; then log "would create $KIT_HOME/venv and install ddtrace"; return 0; fi

  local venv="$KIT_HOME/venv"
  info "installing ddtrace into $venv"
  if ! python3 -m venv "$venv" 2>/dev/null; then
    warn "python3 -m venv failed (is python3-venv installed?); skipping ddtrace"
    return 0
  fi
  "$venv/bin/pip" install --quiet --upgrade pip
  # ddtrace[llmobs] powers the agent-observability experiment and eval skills.
  if ! "$venv/bin/pip" install --quiet 'ddtrace[llmobs]'; then
    warn "could not install ddtrace; the agent-observability skills will need it installed manually"
    return 0
  fi
  ok "ddtrace -> $venv (activate with: . $venv/bin/activate)"
}

install_tools() {
  info "installing CLI tools (groups: $TOOL_GROUPS)"
  mkdir -p "$PREFIX" "$KIT_HOME"
  install_pup
  if want_group node;   then install_node; fi
  if want_group k8s;    then install_kubectl; install_helm; fi
  if want_group gh;     then install_gh; fi
  if want_group python; then install_python_deps; fi
  sbx_on_path "$PREFIX"
}

# ================================================================== skills ===

# Frontmatter `name:` of a SKILL.md, or empty when absent.
skill_name_of() {
  awk '
    NR == 1 && $0 != "---" { exit }
    NR > 1  && $0 == "---" { exit }
    /^name:[[:space:]]*/ {
      sub(/^name:[[:space:]]*/, "")
      gsub(/^["'"'"']|["'"'"']$/, "")
      print
      exit
    }
  ' "$1"
}

fetch_skills_repo() {
  local src="$1"
  mkdir -p "$KIT_HOME"
  if [ -d "$src/.git" ]; then
    git -C "$src" fetch --depth 1 origin "$SKILLS_REF" --quiet
    git -C "$src" checkout --quiet --detach FETCH_HEAD
  else
    rm -rf "$src"
    git clone --depth 1 --branch "$SKILLS_REF" --quiet "$SKILLS_REPO" "$src" 2>/dev/null \
      || git clone --depth 1 --quiet "$SKILLS_REPO" "$src"
  fi
}

# Skill names collide inside agent-skills: k8s-ssi/ and linux-ssi/ each define
# agent-install, enable-ssi, verify-ssi, troubleshoot-ssi and onboarding-summary.
# Any name claimed more than once gets its parent directory prepended. Prefixing
# *every* instance of a duplicated name keeps the result independent of
# traversal order, so re-running the installer is stable.
install_skills() {
  local src="$KIT_HOME/agent-skills"

  info "fetching skills from datadog-labs/agent-skills@$SKILLS_REF"
  if [ "$DRY_RUN" -eq 1 ]; then
    log "would clone $SKILLS_REPO ($SKILLS_REF) and install every SKILL.md into $SKILLS_DIR"
    return 0
  fi

  fetch_skills_repo "$src"
  log "at $(git -C "$src" rev-parse --short HEAD)"

  local skill_files=()
  while IFS= read -r f; do skill_files+=("$f"); done < <(
    find "$src" -name SKILL.md -not -path '*/.git/*' | LC_ALL=C sort
  )
  [ "${#skill_files[@]}" -gt 0 ] || die "no SKILL.md found in $src"

  # Pass 1: count how often each frontmatter name appears.
  local counts="$WORK/skill-names"
  mkdir -p "$counts"
  local f name
  for f in "${skill_files[@]}"; do
    name="$(skill_name_of "$f")"
    case "$name" in ''|*/*|*' '*) continue ;; esac
    printf 'x' >> "$counts/$name"
  done

  # Pass 2: install, disambiguating names that were claimed more than once.
  mkdir -p "$SKILLS_DIR"
  local installed=0 renamed=0 skipped=0
  for f in "${skill_files[@]}"; do
    local dir rel parent target nested
    dir="$(dirname "$f")"
    rel="${dir#"$src"}"; rel="${rel#/}"
    name="$(skill_name_of "$f")"

    case "$name" in
      '')     warn "skipping ${rel:-<root>}/SKILL.md: no name in frontmatter"; skipped=$((skipped + 1)); continue ;;
      */*|*' '*) warn "skipping ${rel:-<root>}/SKILL.md: unusable name '$name'"; skipped=$((skipped + 1)); continue ;;
    esac

    target="$name"
    if [ -z "$rel" ]; then
      # The repo-root SKILL.md is an index over the others; give it a distinct
      # directory so it cannot shadow a real skill.
      target="dd-agent-skills"
    elif [ "$(wc -c < "$counts/$name" | tr -d ' ')" -gt 1 ]; then
      parent="$(basename "$(dirname "$dir")")"
      target="${parent}-${name}"
      renamed=$((renamed + 1))
    fi

    rm -rf "${SKILLS_DIR:?}/$target"
    mkdir -p "$SKILLS_DIR/$target"
    if [ -z "$rel" ]; then
      cp "$f" "$SKILLS_DIR/$target/SKILL.md"
    else
      cp -R "$dir/." "$SKILLS_DIR/$target/"
      # Sub-skills live inside their parent's directory (dd-apm holds the SSI
      # skills, dd-audit holds the investigation skills, and so on). They are
      # installed as skills in their own right, so drop the nested copies.
      while IFS= read -r nested; do
        rm -rf "$(dirname "$nested")"
      done < <(find "$SKILLS_DIR/$target" -mindepth 2 -name SKILL.md)
      find "$SKILLS_DIR/$target" -mindepth 1 -type d -empty -delete
    fi

    # Claude Code resolves a skill by its directory; keep the frontmatter in sync.
    if [ "$target" != "$name" ]; then
      sed "0,/^name:.*/s|^name:.*|name: $target|" "$SKILLS_DIR/$target/SKILL.md" > "$WORK/SKILL.md"
      mv "$WORK/SKILL.md" "$SKILLS_DIR/$target/SKILL.md"
    fi

    installed=$((installed + 1))
    log "${rel:-<root>} -> $target"
  done

  ok "installed $installed skills into $SKILLS_DIR ($renamed renamed to avoid collisions, $skipped skipped)"
}

# ================================================================ settings ===

merge_settings() {
  local key
  if [ "$INSTALL_DOMAINS" -eq 1 ]; then
    key='(.network.datadog.allowedDomains + .network.toolchain.allowedDomains)'
    info "allowing Datadog + toolchain domains in $SETTINGS_FILE"
  else
    key='.network.datadog.allowedDomains'
    info "allowing all Datadog domains in $SETTINGS_FILE"
  fi

  have jq || die "jq is required to merge settings"

  if [ "$DRY_RUN" -eq 1 ]; then
    log "would merge $(jq -r "$key | length" "$KIT_JSON") domains into $SETTINGS_FILE"
    return 0
  fi

  mkdir -p "$(dirname "$SETTINGS_FILE")"
  [ -s "$SETTINGS_FILE" ] || printf '{}\n' > "$SETTINGS_FILE"

  local domains
  domains="$(jq -c "$key" "$KIT_JSON")"
  # Union with whatever is already allowed; never drop an existing entry.
  jq --argjson add "$domains" '
    .sandbox //= {} |
    .sandbox.network //= {} |
    .sandbox.network.allowedDomains = (((.sandbox.network.allowedDomains // []) + $add) | unique)
  ' "$SETTINGS_FILE" > "$WORK/settings.json"
  mv "$WORK/settings.json" "$SETTINGS_FILE"
  ok "$(jq -r '.sandbox.network.allowedDomains | length' "$SETTINGS_FILE") domains allowed"
}

# ===================================================================== mcp ===

install_mcp() {
  if ! have claude; then
    warn "claude CLI not found; skipping MCP server registration"
    return 0
  fi
  info "registering Datadog MCP servers"
  local n url
  while IFS=$'\t' read -r n url; do
    if [ "$DRY_RUN" -eq 1 ]; then
      log "would run: claude mcp add --scope user --transport http $n $url"
    else
      claude mcp add --scope user --transport http "$n" "$url" \
        || warn "could not register $n"
    fi
  done < <(jq -r '.mcp.servers[] | [.name, .url] | @tsv' "$KIT_JSON")
  warn "each MCP server still needs an interactive login (/mcp in Claude Code)"
}

# ==================================================================== main ===

main() {
  info "sbx kit: datadog"
  [ -f "$KIT_JSON" ] || die "kit.json not found at $KIT_JSON"
  WORK="$(mktemp -d)"

  bootstrap_base_tools
  if [ "$DO_TOOLS" -eq 1 ];    then install_tools;   fi
  if [ "$DO_SKILLS" -eq 1 ];   then install_skills;  fi
  if [ "$DO_SETTINGS" -eq 1 ]; then merge_settings;  fi
  if [ "$DO_MCP" -eq 1 ];      then install_mcp;     fi

  printf '\n' >&2
  ok "datadog kit ready"
  if [ "$DO_TOOLS" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
    log "next: run 'pup auth login' to authenticate against your Datadog site"
  fi
}

main "$@"
