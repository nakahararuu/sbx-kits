# claude-dev-plugins

小〜中規模の開発ワークフロー向けに、Claude Code の公式マーケットプレイス（`anthropics/claude-plugins-official`）から厳選した plugin をインストールする mixin kit。

## インストール内容

- **uvx シンボリックリンク** — sandbox には `uv` 本体がベースイメージにプリインストールされているが、`uvx` エントリポイントは含まれていない。serena plugin の MCP サーバー起動（`uvx --from git+https://github.com/oraios/serena serena start-mcp-server`）に必要なため、既存の `uv` バイナリへの `uvx` シンボリックリンクを `/usr/local/bin` に作成する（`uv` は argv0 で `uv`/`uvx` の挙動を切り替えるため、シンボリックリンクだけで動作する）
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
| serena の Python 依存関係解決（uv 経由） | `pypi.org`, `files.pythonhosted.org` |
| context7 MCP server の npx install | `registry.npmjs.org` |
| context7 MCP server の実行時 API | `context7.com`, `mcp.context7.com` |

**注意:** serena は言語ごとの language server を初回利用時にオンデマンドでダウンロードすることがある。特定言語の解析でネットワークブロックが発生した場合は、エラーメッセージに出てくるドメインを `network.allowedDomains` に追記して再適用すること（`.claude/rules/kit-spec.md` 参照）。

## 使い方

```bash
sbx run claude --kit /path/to/claude-dev-plugins/
```

see: https://docs.docker.com/ai/sandboxes/customize/kits/
