# langfuse-claude

Anthropic公式マーケットプレイス（`anthropics/claude-plugins-official`）の `langfuse` plugin（中身は単一の skill）を追加し、それをフル活用するための `langfuse-cli` をインストールする mixin kit。

## インストール内容

1. `claude plugin marketplace add anthropics/claude-plugins-official` でマーケットプレイスを追加
2. `claude plugin install langfuse@claude-plugins-official` で Langfuse skill plugin を追加
3. `npm install -g langfuse-cli` — skill が API アクセスに使う companion CLI（[langfuse/langfuse-cli](https://github.com/langfuse/langfuse-cli)）

## 認証情報

`langfuse-cli` および skill は以下の環境変数で認証する。

```bash
LANGFUSE_PUBLIC_KEY=pk-lf-...
LANGFUSE_SECRET_KEY=sk-lf-...
LANGFUSE_HOST=https://cloud.langfuse.com   # 省略時のデフォルト。US cloud は https://us.cloud.langfuse.com、JP cloud は https://jp.cloud.langfuse.com、self-host は各自のURL
```

（`LANGFUSE_BASE_URL` も同義でサポートされるが、`langfuse-cli` が実際に読むのは `LANGFUSE_HOST`。）

Langfuse の認証は publicKey/secretKey を組み合わせた HTTP Basic。この kit は `spec.yaml` の `credentials` ブロックで、2つの生キーではなく **その組み合わせ済みの Basic 認証値**（`base64("publicKey:secretKey")`）を1つの secret（service: `langfuse`）として要求する（[kit-author: bindings](https://github.com/docker/sbx-kits-contrib/blob/main/skills/kit-author/topics/bindings.md) 参照）。この値は `proxyManaged: true` で、`Authorization: Basic %s` として `cloud.langfuse.com` / `us.cloud.langfuse.com` / `jp.cloud.langfuse.com` 宛のリクエストにプロキシが直接セットする。実値はサンドボックス内には一切入らない。

ホストの `~/.config/sbx/credentials.yaml` に `langfuse` の binding が無い状態でこの kit を使うと、サンドボックス作成時に対話的に「どの環境変数 / ファイルから値を読むか」を聞かれ、一度答えれば以降は自動解決される。binding を先に自分で用意したい場合は次のように書く（値は事前に base64 エンコードしておくこと。`sbx` に base64 エンコード用の `filter` はまだ無い — [docker/sbx-releases#292](https://github.com/docker/sbx-releases/issues/292) 参照）。

```bash
echo -n "$LANGFUSE_PUBLIC_KEY:$LANGFUSE_SECRET_KEY" | base64
```

```yaml
# ~/.config/sbx/credentials.yaml
bindings:
  langfuse:
    discovery:
      - env: [LANGFUSE_BASIC_AUTH]   # base64("publicKey:secretKey") を入れておく
    allowedDomains:
      - cloud.langfuse.com
      - us.cloud.langfuse.com
      - jp.cloud.langfuse.com
```

`langfuse-cli` 自身は `LANGFUSE_PUBLIC_KEY` / `LANGFUSE_SECRET_KEY` の2変数からBasic認証ヘッダを組み立てる作りなので、CLIが起動時に「未設定」で弾かないよう、spec.yaml の `environment.variables` にダミー値（`pk-lf-proxy-managed` / `sk-lf-proxy-managed`）を静的に設定している。CLIがこの2値から組み立てるヘッダの中身はどうであれ、実際に Langfuse Cloud へ送られる時点でプロキシが `Authorization` ヘッダを上記の実値で上書きするため、ダミー値が外部に漏れることはない。

`LANGFUSE_HOST` は `credentials` の対象ではない（通信の宛先そのものであり、注入対象の値ではないため）。デフォルトの `https://cloud.langfuse.com` で問題なければ何もする必要はない。US cloud やセルフホストを使う場合は、サンドボックス内で `export LANGFUSE_HOST=...` するか、`.env` ファイル（`langfuse --env .env api ...`）で指定する。セルフホストの場合は宛先ホストが `network.allow` にも入っている必要があるため、この kit をフォークして該当ホストを追加すること。

## ネットワーク

| 用途 | ドメイン |
|------|----------|
| マーケットプレイスの git clone / GitHub API | `github.com`, `api.github.com` |
| langfuse-cli の npm install | `registry.npmjs.org` |
| Langfuse Cloud API（EU）・ドキュメント | `langfuse.com`, `*.langfuse.com` |
| Langfuse Cloud API（US） | `us.cloud.langfuse.com` |
| Langfuse Cloud API（JP） | `jp.cloud.langfuse.com` |

セルフホストの Langfuse を使う場合は、そのホストも `network.allow` に追加する必要がある（上記参照）。

## 使い方

```bash
sbx run claude --kit /path/to/langfuse-claude/
```

see: https://docs.docker.com/ai/sandboxes/customize/kits/
