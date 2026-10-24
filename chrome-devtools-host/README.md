# chrome-devtools-host

サンドボックス内の Claude Code から、**ホスト側で起動した Chrome** を公式の `chrome-devtools-mcp` plugin（anthropics/claude-plugins-official マーケットプレイス）経由で操作できるようにする mixin kit。サンドボックス内で Chrome 自体を起動するのではなく、ホストの Chrome にリモートデバッグ接続する構成が前提。

## 事前準備（ホスト側）

Chrome をリモートデバッグ有効・全interfaceバインドで起動しておく（サンドボックス起動前に一度）。

```bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --remote-debugging-address=0.0.0.0 \
  --remote-allow-origins='*' \
  --user-data-dir=/tmp/chrome-devtools-host-profile \
  --no-first-run
```

`--remote-debugging-address` は必ず `0.0.0.0`。デフォルトの `127.0.0.1` だと Docker からの接続を拒否される。

`--user-data-dir` も必須。普段使っている profile で Chrome が既に起動していると、このコマンドを叩いても singleton 制限に引っかかって既存インスタンスにウィンドウが1つ開くだけになり、remote debugging は有効化されない(デバッグ用フラグは新規プロセス起動時にしか反映されないため)。`/tmp` 配下などの専用ディレクトリを指定して別プロファイルとして起動することで、確実に新しいインスタンスを起動させる。

## インストール内容

1. **公式 chrome-devtools-mcp plugin**（upstream のマーケットプレイスから直接）— `claude plugin marketplace add ChromeDevTools/chrome-devtools-mcp --sparse .claude-plugin skills` → `claude plugin install chrome-devtools-mcp@chrome-devtools-plugins`
2. **ホスト側の Chrome への接続設定**（`lifecycle@1` の `startup` hook、2エントリ）— サンドボックス起動のたびに、①plugin がホスト側の Chrome に接続するようパッチし、②`localhost:9222 -> host.docker.internal:9222` の接続ブリッジ(`socat`、`background: true`)が起動していなければ起動する(いずれも idempotent)

## なぜ `--sparse` を付けるのか（submodule 回避）

upstream リポジトリには submodule `third_party/devtools-frontend`（github.com）があり、その中にさらに `build` / `buildtools` / `depot_tools` / `inspector_protocol` / `lldb-eval` / `llvm-project` / `clang-format` の submodule（すべて `chromium.googlesource.com`）がある（孫より深い submodule は無い）。Claude Code はマーケットプレイスを `git clone --depth 1 --recurse-submodules --shallow-submodules` で取得するので、`--sparse` が無いとこれらを全部 clone しようとする。

- `chromium.googlesource.com` が許可されていないと 403 で clone が失敗し、Claude Code が SSH にフォールバックして `known_hosts` のエラーで終わる（表に出るのはこの SSH のエラーだけ）
- 許可しても、llvm-project は「まず既定ブランチの先端を shallow clone し、固定コミットが無ければ改めて fetch する」ため 2 回取得され、計 2.7GB・2 分超になる。Claude Code の git タイムアウト（既定 120s、`CLAUDE_CODE_PLUGIN_GIT_TIMEOUT_MS`）を超えて打ち切られる（sbx-kit-claude:2.1.267 で実測）

`--sparse` で sparsePaths を指定すると、Claude Code は submodule を取らない `--filter=blob:none --no-checkout` + sparse-checkout で clone し、マーケットプレイスの更新時も `git submodule update` をスキップする。plugin に必要なのは `.claude-plugin/` と `skills/`（cone モードなのでトップレベルのファイルも入る）だけなので、これで足りる。upstream が `hooks/` や `agents/` などを plugin に追加したら sparse のパスにも足すこと。

upstream の [#2835](https://github.com/ChromeDevTools/chrome-devtools-mcp/pull/2835)（`.gitmodules` の `fetchRecurseSubmodules = false` と、`npm run prepare` の sparse 化）はこの経路には効かない。`fetchRecurseSubmodules` は `git fetch` / `pull` の再帰だけを制御する設定で、`clone --recurse-submodules` には影響しない。

## なぜ plugin.json をパッチするのか

公式 plugin の `plugin.json` はデフォルトで `npx chrome-devtools-mcp@1.6.0` をそのまま起動する設定になっており、`--browser-url` が付いていないためサンドボックス内で自前の Chrome を起動しようとしてしまう。Claude Code には plugin 提供の MCP サーバー設定を宣言的に上書きする仕組みが無く（`claude mcp add` で同名サーバーを user scope に足しても `plugin:chrome-devtools-mcp:chrome-devtools` とは別エントリとして共存するだけで上書きにはならないことを実機で確認済み）、plugin がキャッシュしているファイルを直接書き換えるのが唯一確実な方法。`claude plugin update` などでキャッシュがリセットされる可能性があるため、`lifecycle@1` の `startup` hook で毎回パッチを再適用する。

## なぜ socat が必要か（Host ヘッダー回避）

Chrome の DevTools WebSocket サーバーは `Host` ヘッダーが `localhost:<port>` かIPリテラル以外だと接続を拒否する。MCP サーバーが `host.docker.internal:9222` に直接繋ぐと `Host: host.docker.internal:9222` になり拒否されるが、`socat TCP-LISTEN:9222 -> TCP:host.docker.internal:9222` を経由して `localhost:9222` 宛に接続すれば、Chrome から見える `Host` ヘッダーは `localhost:9222` になり受理される。

`socat` はサンドボックス再起動のたびに消えるため、`lifecycle@1` の `startup` hook で毎回起動し直す設計にしている。

## ネットワーク

| フェーズ | 用途 | ドメイン |
|------|------|----------|
| install | socat / jq の apt-get install（Ubuntu ミラーと、*-docker テンプレートが追加済みの Docker の apt リポジトリ） | `archive.ubuntu.com`, `security.ubuntu.com`, `ports.ubuntu.com`, `download.docker.com` |
| install | upstream のマーケットプレイス・plugin ソースの取得（git clone。`--sparse` で submodule を取らないので `chromium.googlesource.com` は不要） | `github.com`, `api.github.com` |
| runtime | ホストの Chrome DevTools ポートへの接続（socat 経由） | `localhost:9222` |
| runtime | chrome-devtools-mcp の npx 解決（MCP サーバー起動時） | `registry.npmjs.org` |
| runtime | plugin の更新（マーケットプレイスの git fetch。sparsePaths があるので submodule update は走らない） | `github.com`, `api.github.com` |

## 使い方

```bash
sbx run docker.io/docker/sbx-kit-claude:2.1.267 --kit ghcr.io/nakahararuu/sbx-kits/chrome-devtools-host:latest .
```

導入後、Claude から見ると `claude mcp list` に `plugin:chrome-devtools-mcp:chrome-devtools` という名前で（`--browser-url=http://localhost:9222` 付きで）Chrome DevTools ツールが使える。

see: https://docs.docker.com/ai/sandboxes/customize/
