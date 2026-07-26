# datadog-claude

Claude Code 向け Datadog 調査用 mixin kit。

## インストール内容

- **pup CLI** — Datadog 公式 CLI（GitHub Releases からインストール）
- **Claude Datadog plugin** — `claude plugin install datadog@claude-plugins-official`
- **Claude Slack plugin** — `claude plugin install slack@claude-plugins-official`
- **agent skills** — `datadog-labs/agent-skills` から以下の skill をインストール
  - `dd-pup` — pup CLI の使い方・認証・PATH 設定
  - `dd-monitors` — モニターの作成・管理・ミュート
  - `dd-logs` — ログ検索
  - `dd-apm` — トレース・サービス・パフォーマンス
  - `dd-docs` — Datadog ドキュメント検索

## ネットワーク

以下のドメインへのアクセスを許可します。

| 用途 | ドメイン |
|------|----------|
| Datadog API・アプリ（US全リージョン） | `datadoghq.com`, `*.datadoghq.com` |
| Datadog EU | `datadoghq.eu`, `*.datadoghq.eu` |
| Datadog Gov | `ddog-gov.com`, `*.ddog-gov.com` |
| pup CLI インストール | `api.github.com`, `github.com`, `objects.githubusercontent.com` |
| agent skills インストール | `registry.npmjs.org` |
| Slack MCP plugin | `mcp.slack.com`, `slack.com`, `*.slack.com` |

## 使い方

```bash
sbx run claude --kit /path/to/datadog-claude/
```
