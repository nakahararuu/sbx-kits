---
name: kit-v3-author
description: Create a new Docker Sandboxes kit, or migrate/modify an existing one, in this monorepo using kit-spec v3 (`<kit>/<kit>.yaml` with `# syntax=docker/sandbox-kit:3`). Use when the user asks to add a kit, change a kit's network policy/hooks/agent context, port a v2 `spec.yaml` kit, or verify a kit builds. Covers file layout, the v2→v3 field mapping, network-phase splitting, hook env lists, validation with `docker buildx`, and how to try the kit in a real sandbox.
---

# Kit authoring (kit-spec v3)

Every kit in this repo is a kit-spec v3 **mixin** that composes onto a v3 workload (normally `docker.io/docker/sbx-kit-claude`). Pitfalls and links to the spec live in `.claude/rules/kit-spec.md`; read it before writing YAML.

## 1. Lay out the kit

```text
<kit>/
├── <kit>.yaml          # descriptor — first line `# syntax=docker/sandbox-kit:3`
├── <kit>.dockerfile    # optional recipe (overlay baked into the image)
├── <kit>-context.md    # optional agent-context body
└── README.md           # Japanese, like the other kits
```

The directory name and descriptor stem must match — CI and the PostToolUse hook discover kits by `<kit>/<kit>.yaml`.

Descriptor skeleton (copy from an existing kit such as `datadog-claude/datadog-claude.yaml`):

```yaml
# syntax=docker/sandbox-kit:3
# Docker Sandboxes kit: <one line>. Usage and design notes: see README.md.
schemaVersion: "3"
kind: mixin
version: "1.0.0"
displayName: <Display Name>
description: <one sentence>
sourceUrl: https://github.com/nakahararuu/sbx-kits/tree/main/<kit>
requires: ["claude"]            # only if hooks/context assume the claude CLI

capabilities:
  - type: com.docker.sandbox/network-policy@1
    config:
      install:
        allow: [...]            # hosts install hooks reach
      runtime:
        allow: [...]            # hosts the agent and startup hooks reach
  - type: com.docker.sandbox/lifecycle@1
    config:
      install:
        - command: |
            set -e
            ...
          user: "1000"          # "0" for root
          env: [HTTP_PROXY, HTTPS_PROXY, NO_PROXY]
          description: ...
      startup:
        - command: [bash, -c, "..."]   # must be idempotent — runs every boot
          user: "1000"
          background: true             # startup only
          description: ...
  - type: com.docker.sandbox/agent-context@1
    config:
      contentFile: ./<kit>-context.md
```

There is no top-level `name:`. Unknown fields anywhere fail the build.

## 2. Map v2 concepts (when porting a `spec.yaml`)

| v2 | v3 |
| --- | --- |
| `spec.yaml` | `<kit>.yaml` + syntax line, `schemaVersion: "3"`, drop `name:` |
| `agentInstructions.content` | `agent-context@1` with `contentFile: ./<kit>-context.md` |
| `permissions.network.allow/deny` | `network-policy@1`, split into `install` / `runtime` (startup-hook hosts → runtime; never lose a host from the union) |
| `setup.install[]` | `lifecycle@1.install[]` (+ `env:` list) |
| `setup.startup[]` | `lifecycle@1.startup[]` (`background` stays here only) |
| `setup.files[]` / `files/workspace/*` | `lifecycle@1.files[]` with `path: "${{ kit.env.WORKSPACE_DIR }}/..."` |
| `files/home/*` | `COPY` in `<kit>.dockerfile` |
| `credentials[]` | one `credential@1` per (service, phase), add `optional: true` to keep v2's not-required default |
| `${WORKDIR}` | `${{ kit.env.WORKSPACE_DIR }}` (files) / `env: [WORKSPACE_DIR]` + `$WORKSPACE_DIR` (hooks) |

Keep command bodies, users, and descriptions as they were unless the user asked for a behaviour change. Mark deliberate deviations with a `# MIGRATION NOTE:` comment, as docker/sbx-kits-contrib's `v3` branch does.

## 3. Decide hook vs. recipe

For each install hook ask whether it could be a `<kit>.dockerfile` instead: a pinned binary download is better baked into the overlay (no sandbox-time network grant, reproducible). Keep it as a hook when it runs `apt-get`, merges into files the base also writes (`claude plugin install`, `~/.claude/settings.json`), needs a create-time value, or needs the in-sandbox Docker daemon (and Docker-dependent work belongs in `startup`, since the socket isn't mounted during install).

## 4. Validate

```bash
docker buildx build <kit> -f <kit>/<kit>.yaml --output type=cacheonly
```

The PostToolUse hook runs this automatically after you edit any file under a kit directory and feeds failures back. Fix every error it reports — it names the field and line. Do not use `sbx kit validate`; it rejects v3 source kits.

## 5. Try it in a sandbox (host side)

Build success says nothing about network grants or hook behaviour. Ask the user to run on the host (the sandbox you're in usually can't create sandboxes):

```bash
sbx run docker.io/docker/sbx-kit-claude:<tag> --kit ./<kit> .
# or, once pushed:
sbx run docker.io/docker/sbx-kit-claude:<tag> --kit "git+https://github.com/nakahararuu/sbx-kits.git#ref=<branch>&dir=<kit>" .
```

`sbx kit add` can't add mixins to an existing v3 sandbox — recreate instead. Blocked hosts show up as HTTP 403 in `/var/log/sbx-kit-startup.log` (inside) or `sbx policy log` (host); add them to the right phase and retry.

## 6. Finish

- Write/refresh the kit's `README.md` (Japanese): what it installs, network table with phases, usage command.
- Add a row to the kit table in the root `README.md`.
