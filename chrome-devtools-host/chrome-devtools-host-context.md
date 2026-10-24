This sandbox is set up to control a Chrome browser running on the **host** machine
(not inside the sandbox) via the `chrome-devtools-mcp` plugin, installed directly
from its own marketplace in the upstream ChromeDevTools/chrome-devtools-mcp repo
(rather than the anthropics/claude-plugins-official mirror), so plugin updates and
bundled skills track upstream `main` as soon as they're published.

Prerequisite (host side, one-time per host restart): the user must launch Chrome on
the host with remote debugging bound to all interfaces:

  /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
    --remote-debugging-port=9222 \
    --remote-debugging-address=0.0.0.0 \
    --remote-allow-origins='*' \
    --user-data-dir=/tmp/chrome-devtools-host-profile \
    --no-first-run

`--remote-debugging-address=0.0.0.0` is required — the default 127.0.0.1 rejects
connections coming from Docker. `--user-data-dir` pointing at a scratch directory is
also required — if Chrome is already running under the user's normal profile, this
command just opens a new window in that existing (singleton) instance and remote
debugging never actually gets enabled, since debugging flags only take effect when a
fresh instance starts. Using a separate profile forces a genuinely new instance to
launch (at the cost of not having the user's normal cookies/extensions there).

What this kit already did:
- Installed the `chrome-devtools-mcp@chrome-devtools-plugins` plugin directly from
  the upstream ChromeDevTools/chrome-devtools-mcp repo's own marketplace (appears as
  `plugin:chrome-devtools-mcp:chrome-devtools` in `claude mcp list`).
- Patched that plugin's cached `.claude-plugin/plugin.json` to append
  `--browser-url=http://localhost:9222` to its launch args, so it connects to the
  host's Chrome instead of launching its own inside the sandbox. This patch is
  re-applied idempotently on every sandbox boot, since a `claude plugin update` can
  reset the plugin's cached files and drop it.
- Starts a background `socat` process on every sandbox boot that forwards
  `localhost:9222` -> `host.docker.internal:9222`.

Why the socat bridge exists: Chrome's DevTools WebSocket endpoint rejects any
handshake whose `Host` header isn't `localhost:<port>` or an IP literal. Connecting
directly to `host.docker.internal:9222` sends `Host: host.docker.internal:9222`, so
Chrome refuses it. Routing through
`socat TCP-LISTEN:9222,fork,reuseaddr TCP:host.docker.internal:9222` makes the
request Chrome actually sees arrive with `Host: localhost:9222`, which it accepts.
Never point `--browser-url` at `host.docker.internal:9222` directly — always go
through `localhost:9222`.

If MCP tool calls time out, are refused, or `claude mcp list` shows the
`chrome-devtools` server invoked without `--browser-url`, check in this order:
1. `pgrep -fa socat` — if empty, the bridge died (it does not survive a sandbox
   restart on its own, which is why this kit re-launches it at every startup); restart
   it manually with:
   `socat TCP-LISTEN:9222,fork,reuseaddr TCP:host.docker.internal:9222 &`
2. Check whether the plugin's cached `plugin.json` still has `--browser-url` in its
   args (`grep -r browser-url ~/.claude/plugins/cache/chrome-devtools-plugins/chrome-devtools-mcp/*/.claude-plugin/plugin.json`);
   if a plugin update reset it, re-run this kit's patch startup command, or restart
   the sandbox.
3. `curl -s http://localhost:9222/json/version` — should return Chrome's version JSON
   if both the bridge and the host Chrome are up. If it hangs or refuses, ask the
   user to confirm Chrome is running on the host with the flags above, including
   `--user-data-dir`. Without it, if Chrome was already running under the user's
   normal profile, the launch command silently no-ops into that existing instance
   and remote debugging never turns on.
