# datadog

Everything an agent needs to work against Datadog from a sandbox: all of
[`datadog-labs/agent-skills`](https://github.com/datadog-labs/agent-skills), the
CLI tools those skills drive, and a sandbox network policy that allows every
Datadog domain.

```bash
../../install-kit.sh datadog
pup auth login
```

## What it installs

### 1. Skills

Every directory in `datadog-labs/agent-skills` that contains a `SKILL.md` — 39 of
them as of `main` — is copied into `~/.claude/skills/`, assets (`references/`,
`scripts/`, `evals/`) included.

The kit clones the upstream repository and walks it, rather than replaying the
`npx skills add --skill …` list from the upstream README. That list has drifted
from the repository (it omits `dd-security`, `dd-apps`, the
`dd-software-delivery` skills and the v5/v6 Browser SDK upgrades), so walking the
tree is what actually makes "all skills" true, and it stays true as upstream
adds more.

Five names are defined twice — `agent-install`, `enable-ssi`, `verify-ssi`,
`troubleshoot-ssi` and `onboarding-summary` each exist under both
`dd-apm/k8s-ssi/` and `dd-apm/linux-ssi/`. Installing them flat would have one
silently overwrite the other, so any name claimed more than once is prefixed
with its parent directory (`k8s-ssi-agent-install`, `linux-ssi-agent-install`)
and the `name:` in its frontmatter is rewritten to match. Names claimed once are
left alone. The repository-root `SKILL.md` is an index over the others and is
installed as `dd-agent-skills`.

Sub-skills are pruned from their parent's copy, so `dd-apm/` does not ship a
second copy of the ten SSI skills that are already installed on their own.

### 2. CLI tools

| Group | Tools | Needed by |
| --- | --- | --- |
| `core` | `pup`, plus `curl`/`git`/`jq`/`tar` | everything — `pup` is the CLI nearly every skill calls |
| `node` | `node`, `npm`, `npx` (20.19+) | `dd-apps`, `dd-browser-sdk`, `npx skills` |
| `k8s` | `kubectl`, `helm` | the `k8s-ssi-*` skills |
| `gh` | `gh` | `unblock-pr`, which falls back to `gh run rerun` without MCP |
| `python` | `python3` + `ddtrace[llmobs]` in a venv | the `agent-observability-*` skills |

All five install by default; narrow with `--groups core,node`. Binaries land in
`~/.local/bin`, Node.js and the Python venv in
`~/.local/share/sbx-kits/datadog/`. Anything already on `PATH` is left alone, so
the installer is safe to re-run.

`ddtrace` goes into a dedicated venv (`~/.local/share/sbx-kits/datadog/venv`)
rather than the system interpreter. Activate it before running generated
experiment code:

```bash
. ~/.local/share/sbx-kits/datadog/venv/bin/activate
```

`pup` resolves to the newest release via the GitHub API, falling back to the
`/releases/latest` redirect and then to a pinned version. Pin explicitly with
`PUP_VERSION=1.8.0`.

### 3. Network policy

`settings.json` allows every Datadog site and every Datadog-owned apex domain,
subdomains included, and is merged into `~/.claude/settings.json` as a union —
domains already allowed are never dropped.

| Domain | Covers |
| --- | --- |
| `datadoghq.com`, `*.datadoghq.com` | US1, US3, US5, AP1, AP2, UK1 and every subdomain (`app`, `api`, `docs`, `mcp`, `helm`, `install`, `keys`, `tags`, `admission`, …) |
| `datadoghq.eu`, `*.datadoghq.eu` | EU1 |
| `ddog-gov.com`, `*.ddog-gov.com` | US1-FED, US2-FED |
| `datad0g.com`, `*.datad0g.com` | Datadog staging |
| `datadoghq.dev`, `*.datadoghq.dev` | developer docs, Browser SDK typedocs |
| `dtdg.co`, `*.dtdg.co` | Datadog short links |
| `datadoghq-browser-agent.com`, `*.datadoghq-browser-agent.com` | Browser SDK CDN |
| `browser-intake-datadoghq.com`, `browser-intake-us3-datadoghq.com`, `browser-intake-us5-datadoghq.com`, `browser-intake-ap1-datadoghq.com`, `browser-intake-ap2-datadoghq.com`, `browser-intake-datadoghq.eu`, `browser-intake-ddog-gov.com`, `browser-intake-us2-ddog-gov.com` (each with `*.` too) | RUM / Logs browser intake |

The browser-intake hosts are listed one by one on purpose: despite how they
read, `browser-intake-datadoghq.com` is its own apex domain, not a subdomain of
`datadoghq.com`, so the `*.datadoghq.com` wildcard does not reach it.

Apex and wildcard are both listed for every domain because Claude Code treats a
bare entry as an exact host match — `*.datadoghq.com` alone would not allow
`datadoghq.com` itself.

## What it does not allow

`settings.json` contains Datadog domains and nothing else. Two things you may
want on top of it:

- **Toolchain domains.** Downloading `pup`, Node.js, `kubectl`, `helm`, `gh` and
  `ddtrace` needs GitHub, nodejs.org, dl.k8s.io, get.helm.sh and PyPI. If the
  installer runs at image-build time this is moot — it is outside the sandbox
  boundary. If it has to run inside a sandboxed shell, use
  `settings.install.json`, or pass `--install-domains` to merge both sets.
- **Runtime GitHub access.** `unblock-pr`'s `gh run rerun` fallback and
  `triage-flaky-test`'s repo lookups reach `github.com`. Add it yourself if you
  want that path to work; the kit will not widen the policy beyond Datadog on
  its own.

## Authentication

The kit installs tooling; it cannot log you in.

```bash
pup auth login                  # OAuth2, per Datadog site
export DD_SITE=datadoghq.com    # or us3./us5./ap1./ap2.datadoghq.com, datadoghq.eu, ddog-gov.com
```

The `dd-audit` skills call the Audit REST API directly and need keys with the
`audit_logs_read` scope; `dd-apps` needs keys with Actions API access:

```bash
export DD_API_KEY=<api-key>
export DD_APP_KEY=<app-key>
```

## MCP servers (optional)

`agent-observability` requires the Datadog MCP server, and
`dd-software-delivery` prefers it over `pup`. `--with-mcp` registers all three
toolsets with `claude mcp add`; each still needs an interactive OAuth login via
`/mcp`.

```bash
../../install-kit.sh datadog -- --with-mcp
```

## Options

```
--groups LIST        core,node,k8s,gh,python (core is always installed)
--skills-only        skills only
--tools-only         tools only
--settings-only      network policy only
--no-settings        leave settings.json alone
--with-mcp           register the Datadog MCP servers
--install-domains    allow toolchain domains too
--ref REF            git ref of datadog-labs/agent-skills (default: main)
--skills-dir DIR     default ~/.claude/skills
--prefix DIR         default ~/.local/bin
--settings FILE      default ~/.claude/settings.json
--dry-run            print, change nothing
```

Environment overrides: `SBX_DATADOG_SKILLS_REF`, `SBX_DATADOG_SKILLS_DIR`,
`SBX_DATADOG_PREFIX`, `SBX_DATADOG_HOME`, `SBX_DATADOG_SETTINGS`,
`PUP_VERSION`, `NODE_VERSION`, `HELM_VERSION`, `GH_VERSION`.

## Pinning

`--ref` accepts any git ref, so a sandbox image can pin the skill set:

```bash
./install-kit.sh datadog -- --ref v1.0.3
```

Without it the kit tracks `main`, which is what you want for an image rebuilt
regularly and not what you want for a reproducible build.
