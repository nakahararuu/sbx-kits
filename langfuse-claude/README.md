# langfuse-claude

Anthropic公式マーケットプレイス（`anthropics/claude-plugins-official`）の `langfuse` plugin（中身は単一の skill）を追加し、それをフル活用するための `langfuse-cli` をインストールする mixin kit。

## インストール内容

1. `claude plugin marketplace add anthropics/claude-plugins-official` でマーケットプレイスを追加
2. `claude plugin install langfuse@claude-plugins-official` で Langfuse skill plugin を追加
3. `npm install -g langfuse-cli` — skill が API アクセスに使う companion CLI（[langfuse/langfuse-cli](https://github.com/langfuse/langfuse-cli)）

## 認証情報（ホストの環境変数をサンドボックスに注入する）

`langfuse-cli` および skill は以下の環境変数で認証する。

```bash
LANGFUSE_PUBLIC_KEY=pk-lf-...
LANGFUSE_SECRET_KEY=sk-lf-...
LANGFUSE_HOST=https://cloud.langfuse.com   # 省略時のデフォルト。US cloud は https://us.cloud.langfuse.com、self-host は各自のURL
```

（`LANGFUSE_BASE_URL` も同義でサポートされるが、`langfuse-cli` が実際に読むのは `LANGFUSE_HOST`。）

`sbx run` / `sbx create` に汎用の env passthrough フラグは無いため、この kit 自体は spec.yaml から動的にホストの環境変数を読み込めない。代わりに、`LANGFUSE_PUBLIC_KEY` / `LANGFUSE_SECRET_KEY` はホスト側で `sbx secret set-custom` を使ってプレースホルダーとしてサンドボックスに注入する（実値はプロキシが対象ホストへの通信時にのみ差し替えるため、サンドボックス内に生の値は入らない）。**ホストの現在のシェルにこれらの環境変数が設定済みであること**が前提。

```bash
# ホスト側で一度実行（-g で全サンドボックス共通。特定のサンドボックスだけに限定する場合は -g の代わりに <sandbox名> を指定）
sbx secret set-custom -g \
  --host cloud.langfuse.com --host us.cloud.langfuse.com \
  --env LANGFUSE_PUBLIC_KEY --value "$LANGFUSE_PUBLIC_KEY"

sbx secret set-custom -g \
  --host cloud.langfuse.com --host us.cloud.langfuse.com \
  --env LANGFUSE_SECRET_KEY --value "$LANGFUSE_SECRET_KEY"
```

`LANGFUSE_HOST` はプロキシが通信の宛先を決めるために使う値そのものであり、上記のプレースホルダー置換の対象にはできない（宛先ホスト名自体は差し替えられない）。デフォルトの `https://cloud.langfuse.com` で問題なければ何もする必要はない。US cloud やセルフホストを使う場合は、サンドボックス内で `export LANGFUSE_HOST=...` するか、`.env` ファイル（`langfuse --env .env api ...`）で指定する。セルフホストの場合は宛先ホストが `network.allow` にも入っている必要があるため、この kit をフォークして該当ホストを追加すること。

## ネットワーク

| 用途 | ドメイン |
|------|----------|
| マーケットプレイスの git clone / GitHub API | `github.com`, `api.github.com` |
| langfuse-cli の npm install | `registry.npmjs.org` |
| Langfuse Cloud API（EU）・ドキュメント | `langfuse.com`, `*.langfuse.com` |
| Langfuse Cloud API（US） | `us.cloud.langfuse.com` |

セルフホストの Langfuse を使う場合は、そのホストも `network.allow` に追加する必要がある（上記参照）。

## 使い方

```bash
sbx run claude --kit /path/to/langfuse-claude/
```

see: https://docs.docker.com/ai/sandboxes/customize/kits/
