# claude-dev-plugins

小〜中規模の開発ワークフロー向けに、Claude Code の公式マーケットプレイス（`anthropics/claude-plugins-official`）から厳選した plugin をインストールする mixin kit。

## インストール内容

- **uv** — `uvx` を提供する Python パッケージランナー。serena plugin の MCP サーバー起動（`uvx --from git+https://github.com/oraios/serena serena start-mcp-server`）に必要なため、`/usr/local/bin` に直接インストールする（shell rc 経由の PATH 設定に依存しないため、Claude Code が起動する MCP サーバープロセスからも確実に見える）
- **plugin 一式**（`claude plugin marketplace add anthropics/claude-plugins-official` の後、以下を install）
  - `context7` — 最新のライブラリドキュメント・コード例をプロンプトに取り込む MCP server（Upstash 提供）
  - `feature-dev` — 探索・設計・実装・レビューを担当する agent を揃えた機能開発ワークフロー
  - `code-review` — 複数 agent による PR の自動コードレビュー（confidence スコアで false positive を抑制）
  - `pr-review-toolkit` — コメント・テスト・エラーハンドリング・型設計・簡潔さなど観点別の PR レビュー agent 群
  - `commit-commands` — commit / push / PR 作成の git ワークフロー用コマンド
  - `security-guidance` — 編集時のパターンベース警告、Stop 時の LLM diff レビュー、コミット時のセキュリティレビュー agent
  - `serena` — LSP を用いたセマンティックなコード理解・リファクタリング支援 MCP server

## ネットワーク

以下のドメインへのアクセスを許可します。

| 用途 | ドメイン |
|------|----------|
| マーケットプレイス取得・plugin install（git clone / API / release asset） | `github.com`, `api.github.com`, `objects.githubusercontent.com` |
| uv インストーラー（`astral.sh` は `releases.astral.sh` にリダイレクトされる） | `astral.sh`, `releases.astral.sh` |
| serena の Python 依存関係解決（uv 経由） | `pypi.org`, `files.pythonhosted.org` |
| context7 MCP server の npx install | `registry.npmjs.org` |
| context7 MCP server の実行時 API | `context7.com`, `mcp.context7.com` |

**注意:** serena は言語ごとの language server を初回利用時にオンデマンドでダウンロードすることがある。特定言語の解析でネットワークブロックが発生した場合は、エラーメッセージに出てくるドメインを `network.allowedDomains` に追記して再適用すること（`.claude/rules/kit-spec.md` 参照）。

## 使い方

```bash
sbx run claude --kit /path/to/claude-dev-plugins/
```

see: https://docs.docker.com/ai/sandboxes/customize/kits/
