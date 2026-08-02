# langfuse-claude

Claude Code のセッション（LLM呼び出し・ツール呼び出し・トークン使用量）を、サンドボックス内にセルフホストした [Langfuse](https://langfuse.com) へ自動送信し、可視化する mixin kit。

## インストール内容

- **Langfuse スタック** — 公式の `docker-compose.yml`（langfuse-web / langfuse-worker / postgres / clickhouse / redis / minio）を `/opt/langfuse` に配置し、サンドボックス起動のたびに `docker compose up -d` で起動
- **langfuse-observability plugin** — 公式マーケットプレイス（`anthropics/claude-plugins-official` 掲載、実体は `langfuse/claude-observability-plugin`）からインストール。Stop/SessionEnd hook で `claude` CLI のセッションを incrementally 読み取り、ターンごとに Langfuse へ trace を送信する
- **langfuse-cli** — 公式の npm 版 CLI（`langfuse/langfuse-cli`）をグローバルインストール
- **langfuse skill** — 公式マーケットプレイスの `langfuse` plugin（実体は `langfuse/skills.git`）。trace/prompt/dataset を Langfuse API 経由でクエリできる skill

収集したテレメトリは、ホストのブラウザ（Web UI）と、サンドボックス内の `claude` 自身（langfuse-cli / langfuse skill 経由）の両方から参照できます。`LANGFUSE_PUBLIC_KEY` / `LANGFUSE_SECRET_KEY` / `LANGFUSE_BASE_URL` は `/etc/sandbox-persistent.sh` に export されており、`claude` が実行するコマンドすべてに自動で渡ります。

## 認証情報の扱い

このkitは `credentials:` ブロックを使いません。Langfuse サーバーと、それに送信する plugin の両方が同じサンドボックス内で完結するため、ホスト側の `sbx secret set` は不要です。

`commands.install` 実行時に以下をすべてローカルで生成し、`/opt/langfuse/.env` に書き込みます。

- Postgres / ClickHouse / Redis / MinIO のパスワード
- Langfuse の `NEXTAUTH_SECRET` / `SALT` / `ENCRYPTION_KEY`
- Langfuse プロジェクトの API キーペア（`pk-lf-...` / `sk-lf-...`）

生成した API キーペアは、Langfuse 側の初回起動時プロビジョニング（`LANGFUSE_INIT_PROJECT_PUBLIC_KEY` / `LANGFUSE_INIT_PROJECT_SECRET_KEY`）と、plugin 側の設定（`claude plugin install ... --config LANGFUSE_PUBLIC_KEY=... --config LANGFUSE_SECRET_KEY=...`）の両方に同じ値を渡すことで、Langfuse の API を呼ばずに鍵を一致させています。

## 使い方

```bash
sbx run claude --kit /path/to/langfuse-claude/
```

普段通り `claude` を使うだけで、ターンごとに自動でトレースが送信されます。

- トレース対象は `claude` CLI セッションと Desktop アプリの **Code mode** のみ。Desktop の通常 Chat mode は hook が発火しないため対象外
- Langfuse の Web UI はコンテナのポート3000で待ち受けています。ダッシュボードをブラウザで見るには、ホストで以下を実行してください（このkit-spec バージョンには `ports:` によるポート自動公開機能がないため、手動公開が必要です）
  ```bash
  sbx ports <sandbox名> --publish 3000:3000
  ```
- ログイン情報（メールアドレス・パスワード）は `/opt/langfuse/.env` の `LANGFUSE_INIT_USER_EMAIL` / `LANGFUSE_INIT_USER_PASSWORD` を参照してください

## トラブルシューティング

- トレースが出ない場合、まず `~/.claude/state/langfuse_hook.log` を確認してください（plugin は fail-open 設計のため、Langfuse 未起動や鍵不整合、`uv` 未検出などがあっても `claude` の動作自体は止まりません）
- Langfuse コンテナの起動状況: `docker compose -f /opt/langfuse/docker-compose.yml ps`（`clickhouse` と `postgres` は初回起動時に healthy になるまで時間がかかります）

## ネットワーク

以下のドメインへのアクセスを許可します。

| 用途 | ドメイン |
|------|----------|
| plugin marketplace 追加・インストール（GitHub） | `github.com`, `api.github.com`, `objects.githubusercontent.com` |
| Langfuse Python SDK の初回ダウンロード（`uv run --script` 経由） | `pypi.org`, `files.pythonhosted.org` |
| minio イメージ（`cgr.dev/chainguard/minio`）の pull | `cgr.dev` |

Docker イメージの pull は `commands.startup` 内の `docker compose up -d` で行われます（Docker ソケットが使えるのは startup 以降のため。`docker-amd64` kit と同じ制約）。実際にこのサンドボックス環境で検証したところ、`docker.io` からの pull（`langfuse/*`, `clickhouse/clickhouse-server`, `redis`, `postgres`）は `caps.network.allow` に何も書かなくても成功しました。一方 `cgr.dev`（minio イメージのレジストリ）は許可リストに無いドメインとしてサンドボックスのネットワークポリシーに 403 で弾かれたため、上表のとおり明示的に allow しています。

## スコープ外

Claude Code 本体が持つ native OpenTelemetry メトリクス/ログ出力（`CLAUDE_CODE_ENABLE_TELEMETRY`）はこのkitでは扱いません。ここで送っているのは langfuse-observability plugin による LLM/ツール呼び出しのトレースのみです。
