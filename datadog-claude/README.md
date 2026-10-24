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

| フェーズ | 用途 | ドメイン |
|------|------|----------|
| install | pup CLI インストール（GitHub Releases）・plugin install | `github.com`, `api.github.com`, `objects.githubusercontent.com` |
| install | agent skills インストール（npx skills add） | `registry.npmjs.org` |
| runtime | Datadog API・アプリ（US全リージョン） | `datadoghq.com`, `*.datadoghq.com` |
| runtime | Datadog EU | `datadoghq.eu`, `*.datadoghq.eu` |
| runtime | Datadog Gov | `ddog-gov.com`, `*.ddog-gov.com` |
| runtime | plugin の更新（マーケットプレイスの git fetch） | `github.com`, `api.github.com` |
| runtime | Slack MCP plugin | `mcp.slack.com`, `slack.com`, `*.slack.com` |

## 使い方

```bash
sbx run docker.io/docker/sbx-kit-claude:2.1.267 --kit ghcr.io/nakahararuu/sbx-kits/datadog-claude:latest .
```
