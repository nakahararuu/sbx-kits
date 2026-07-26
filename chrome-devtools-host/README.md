# chrome-devtools-host

サンドボックス内の Claude Code から、**ホスト側で起動した Chrome** を chrome-devtools-mcp 経由で操作できるようにする mixin kit。サンドボックス内で Chrome 自体を起動するのではなく、ホストの Chrome にリモートデバッグ接続する構成が前提。

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

1. **socat** — `apt-get install socat`
2. **chrome-devtools-mcp@1.6.0** — `npm install -g`
3. **MCP サーバー登録** — `claude mcp add chrome-devtools-host --scope user -- npx chrome-devtools-mcp@1.6.0 --browser-url=http://localhost:9222`
4. **socat ブリッジの自動起動**（`commands.startup`, `background: true`）— サンドボックス起動のたびに `localhost:9222 -> host.docker.internal:9222` の TCP フォワードを立ち上げる（idempotent: 既に起動していればスキップ）

## なぜ socat が必要か（Host ヘッダー回避）

Chrome の DevTools WebSocket サーバーは `Host` ヘッダーが `localhost:<port>` かIPリテラル以外だと接続を拒否する。MCP サーバーが `host.docker.internal:9222` に直接繋ぐと `Host: host.docker.internal:9222` になり拒否されるが、`socat TCP-LISTEN:9222 -> TCP:host.docker.internal:9222` を経由して `localhost:9222` 宛に接続すれば、Chrome から見える `Host` ヘッダーは `localhost:9222` になり受理される。

`socat` はサンドボックス再起動のたびに消えるため、`commands.startup` で毎回起動し直す設計にしている。

## agentContext

上記の背景（ホスト Chrome の起動方法、socat ブリッジが必要な理由、`--browser-url` を必ず `localhost:9222` に向けること、トラブルシュート手順）を agent memory に注入する。サンドボックス内の Claude がこの kit の存在だけを見て、Host ヘッダーの罠にハマらないようにするため。

## ネットワーク

| 用途 | ドメイン |
|------|----------|
| ホストの Chrome DevTools ポートへの接続（socat 経由） | `localhost:9222` |
| chrome-devtools-mcp の npm インストール/解決 | `registry.npmjs.org` |

## 使い方

```bash
sbx run claude --kit /path/to/chrome-devtools-host/
```

導入後、Claude から `chrome-devtools-host` という名前の MCP サーバーとして Chrome DevTools ツールが使える。

see: https://docs.docker.com/ai/sandboxes/customize/kits/
