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
LANGFUSE_HOST=https://cloud.langfuse.com   # 省略時のデフォルト。US cloud は https://us.cloud.langfuse.com、self-host は各自のURL
```

（`LANGFUSE_BASE_URL` も同義でサポートされるが、`langfuse-cli` が実際に読むのは `LANGFUSE_HOST`。）

`LANGFUSE_PUBLIC_KEY` / `LANGFUSE_SECRET_KEY` はこの kit の `spec.yaml` の `credentials` ブロックで宣言している（[kit-author: bindings](https://github.com/docker/sbx-kits-contrib/blob/main/skills/kit-author/topics/bindings.md) 参照）。ホストの `~/.config/sbx/credentials.yaml` に `langfuse-public-key` / `langfuse-secret-key` の binding が無い状態でこの kit を使うと、サンドボックス作成時に対話的に「どの環境変数 / ファイルから値を読むか」を聞かれ、一度答えれば以降は自動解決される。事前に手動でコマンドを叩いておく必要はない。binding を先に自分で用意したい場合は次のように書く。

```yaml
# ~/.config/sbx/credentials.yaml
bindings:
  langfuse-public-key:
    discovery:
      - env: [LANGFUSE_PUBLIC_KEY]
    allowedDomains:
      - cloud.langfuse.com
      - us.cloud.langfuse.com
  langfuse-secret-key:
    discovery:
      - env: [LANGFUSE_SECRET_KEY]
    allowedDomains:
      - cloud.langfuse.com
      - us.cloud.langfuse.com
```

Langfuse の認証は publicKey/secretKey を組み合わせた HTTP Basic で、両方ともユーザー/プロジェクトごとに動的な値のため、`credentials.apiKey.inject` の `scheme: basic` シュガー（動的な値1つ + 固定 `username` の組み合わせ用）では表現できない。そのため両エントリともプロキシ側でのマスク（`proxyManaged: true`）は使わず、実値がそのままサンドボックス内の環境変数に入る（`langfuse-cli` 自身がその2値からBasic認証ヘッダを組み立てる）。`credentials` ブロックを使う主な利点は値の秘匿ではなく、必要な認証情報を kit のメタデータとして宣言し、未設定なら対話的に補完できる点。なお `LANGFUSE_PUBLIC_KEY` は Langfuse 公式ドキュメント上も非秘匿（クライアントサイドでの利用を想定）と明記されている値。

`LANGFUSE_HOST` は `credentials` の対象ではない（通信の宛先そのものであり、注入対象の値ではないため）。デフォルトの `https://cloud.langfuse.com` で問題なければ何もする必要はない。US cloud やセルフホストを使う場合は、サンドボックス内で `export LANGFUSE_HOST=...` するか、`.env` ファイル（`langfuse --env .env api ...`）で指定する。セルフホストの場合は宛先ホストが `network.allow` にも入っている必要があるため、この kit をフォークして該当ホストを追加すること。

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
