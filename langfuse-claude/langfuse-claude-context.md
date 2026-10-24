This sandbox self-hosts Langfuse (https://langfuse.com) via `docker compose` and wires
the official `langfuse-observability` Claude Code plugin (from the
`anthropics/claude-plugins-official` marketplace listing, sourced from
`langfuse/claude-observability-plugin`) to send every Claude Code CLI turn to it.

Architecture:
- `/opt/langfuse/docker-compose.yml` + `/opt/langfuse/.env` define the Langfuse stack:
  langfuse-web, langfuse-worker, postgres, clickhouse, redis, minio. This is the
  upstream `docker-compose.yml` published by the Langfuse project, unmodified except
  for the generated `.env` values.
- All secrets (Postgres/Redis/MinIO passwords, NEXTAUTH_SECRET, SALT, ENCRYPTION_KEY,
  and the Langfuse project's public/secret API key pair) are generated locally with
  `openssl rand` during the install hook and written to `/opt/langfuse/.env`
  (root-readable, world-readable — single-tenant sandbox). Nothing is fetched from or
  sent to a host secret store: this kit needs no `sbx secret set` credential, because
  both the Langfuse server and the plugin that talks to it live in the same sandbox.
- The same generated API key pair is passed twice: as `LANGFUSE_INIT_PROJECT_PUBLIC_KEY`
  / `LANGFUSE_INIT_PROJECT_SECRET_KEY` (Langfuse's own non-interactive bootstrap
  mechanism, which pre-creates an org/project/user with exactly these keys on first
  boot) and as `--config LANGFUSE_PUBLIC_KEY=... --config LANGFUSE_SECRET_KEY=...` when
  installing the Claude Code plugin. Both sides agree on the same key pair without
  calling the Langfuse API to mint one.
- A lifecycle startup hook runs `docker compose up -d` in `/opt/langfuse` on every sandbox
  boot, not in an install hook, because the Docker socket is not mounted yet when
  install hooks run. `docker compose up -d` is idempotent, so this is safe to
  re-run on every start.

This kit also lets Claude itself read the telemetry back, not just a human via the
browser: the official `langfuse-cli` (npm) and the official `langfuse` skill (from
`anthropics/claude-plugins-official`, source `langfuse/skills.git`) are installed
too, and `LANGFUSE_PUBLIC_KEY` / `LANGFUSE_SECRET_KEY` / `LANGFUSE_BASE_URL` are
exported via `/etc/sandbox-persistent.sh` (sourced before every shell command) so
both can query the same local instance without extra setup.

Usage:
- Just use `claude` normally. The `langfuse-observability` plugin's Stop/SessionEnd
  hooks upload each turn in the background; nothing else is required.
- To query traces/prompts/datasets back (e.g. "what did the last run cost?"), ask
  Claude directly — the `langfuse` skill activates automatically — or run
  `langfuse-cli` yourself. A few `langfuse-cli` specifics learned the hard way:
  - Always reach it at `http://localhost:3000`. The sandbox's network policy
    blocks direct access to the Langfuse container's Docker-network IP
    (e.g. `172.x.x.x`) — `LANGFUSE_HOST`/`LANGFUSE_BASE_URL` are already set to
    `localhost`, so this only bites if something overrides them.
  - Langfuse v4's default `events_only` write mode drops legacy read endpoints
    (including `traces list`); use `observations list` instead. The `langfuse`
    skill's own `references/cli.md` mentions this too (framed as `traces list`
    timing out on Cloud) — on self-hosted `events_only` it's a hard error, not
    a timeout, per Langfuse's compatibility docs (langfuse.com/docs/compatibility).
  - Flags are hyphenated (`--from-timestamp`), not camelCase
    (`--fromTimestamp` fails).
- Only `claude` CLI sessions and desktop **Code mode** are traced — regular Claude
  Desktop **Chat mode** does not invoke Claude Code hooks and is never captured.
- Langfuse's web UI listens on container port 3000. This kit does not declare a
  `port@1` capability to auto-publish it: `port@1` binds the host side to an
  ephemeral port chosen by the runtime, but Langfuse is configured with
  `NEXTAUTH_URL=http://localhost:3000`, so login redirects would point at the wrong
  port. Instead, ask the user to run
  `sbx ports <sandbox> --publish 3000:3000` on the host to view the dashboard in a
  browser (see "Publishing ports to the host" in the project's environment notes).
- Login with the email/password in `LANGFUSE_INIT_USER_EMAIL` /
  `LANGFUSE_INIT_USER_PASSWORD` inside `/opt/langfuse/.env`
  (`cat /opt/langfuse/.env` to read the generated password).

Troubleshooting:
- Traces missing: check `~/.claude/state/langfuse_hook.log` first (the plugin fails
  open — a stopped/starting Langfuse stack, a bad key, or a missing `uv` never blocks
  Claude Code, it just skips tracing and logs why).
- Langfuse containers not (yet) healthy: `docker compose -f /opt/langfuse/docker-compose.yml ps`.
  `clickhouse` and `postgres` take the longest to become healthy on a cold first boot.
- No containers running at all: the startup hook may have run before the Docker
  socket was ready and failed outright. Check `cat /var/log/sbx-kit-startup.log` for
  `dial unix /var/run/docker.sock`. Recover with
  `cd /opt/langfuse && docker compose up -d` — `.env` from install is still there.
- This kit does not touch Claude Code's separate native OpenTelemetry metrics/logs
  exporter (`CLAUDE_CODE_ENABLE_TELEMETRY`) — it only wires the Langfuse plugin's
  hook-based LLM/tool tracing, which is what was asked for.
