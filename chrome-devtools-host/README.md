# chrome-devtools-host

サンドボックス内の Claude Code から、**ホスト側で起動した Chrome** を公式の `chrome-devtools-mcp` plugin（anthropics/claude-plugins-official マーケットプレイス）経由で操作できるようにする mixin kit。サンドボックス内で Chrome 自体を起動するのではなく、ホストの Chrome にリモートデバッグ接続する構成が前提。

## 事前準備（ホスト側）

Chrome をリモートデバッグ有効・全interfaceバインドで起動しておく（サンドボックス起動前に一度）。

```bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --remote-debugging-address=0.0.0.0 \
  --remote-allow-origins='*' \
  --no-first-run
```

`--remote-debugging-address` は必ず `0.0.0.0`。デフォルトの `127.0.0.1` だと Docker からの接続を拒否される。

## インストール内容

1. **公式 chrome-devtools-mcp plugin** — `claude plugin marketplace add anthropics/claude-plugins-official` → `claude plugin install chrome-devtools-mcp@claude-plugins-official`
2. **ホスト側の Chrome への接続設定**（`commands.startup`, `background: true`）— サンドボックス起動のたびに、plugin がホスト側の Chrome に接続するようパッチし、`localhost:9222 -> host.docker.internal:9222` の接続ブリッジが起動していなければ起動する(idempotent)

## なぜ plugin.json をパッチするのか

公式 plugin の `plugin.json` はデフォルトで `npx chrome-devtools-mcp@1.6.0` をそのまま起動する設定になっており、`--browser-url` が付いていないためサンドボックス内で自前の Chrome を起動しようとしてしまう。Claude Code には plugin 提供の MCP サーバー設定を宣言的に上書きする仕組みが無く（`claude mcp add` で同名サーバーを user scope に足しても `plugin:chrome-devtools-mcp:chrome-devtools` とは別エントリとして共存するだけで上書きにはならないことを実機で確認済み）、plugin がキャッシュしているファイルを直接書き換えるのが唯一確実な方法。`claude plugin update` などでキャッシュがリセットされる可能性があるため、`commands.startup` で毎回パッチを再適用する。

## なぜ socat が必要か（Host ヘッダー回避）

Chrome の DevTools WebSocket サーバーは `Host` ヘッダーが `localhost:<port>` かIPリテラル以外だと接続を拒否する。MCP サーバーが `host.docker.internal:9222` に直接繋ぐと `Host: host.docker.internal:9222` になり拒否されるが、`socat TCP-LISTEN:9222 -> TCP:host.docker.internal:9222` を経由して `localhost:9222` 宛に接続すれば、Chrome から見える `Host` ヘッダーは `localhost:9222` になり受理される。

`socat` はサンドボックス再起動のたびに消えるため、`commands.startup` で毎回起動し直す設計にしている。

## ネットワーク

| 用途 | ドメイン |
|------|----------|
| ホストの Chrome DevTools ポートへの接続（socat 経由） | `localhost:9222` |
| chrome-devtools-mcp の npx 解決(MCP サーバー起動時) | `registry.npmjs.org` |
| 公式マーケットプレイス・plugin ソースの取得（git clone） | `github.com`, `api.github.com` |

## 使い方

```bash
sbx run claude --kit /path/to/chrome-devtools-host/
```

導入後、Claude から見ると `claude mcp list` に `plugin:chrome-devtools-mcp:chrome-devtools` という名前で（`--browser-url=http://localhost:9222` 付きで）Chrome DevTools ツールが使える。

see: https://docs.docker.com/ai/sandboxes/customize/kits/
