# claude-documentation

Miro・Slack（Anthropic公式マーケットプレイス）と Cosense（旧Scrapbox）のskill/CLIをまとめて導入する mixin kit。

## インストール内容

1. **Miro plugin** — `anthropics/claude-plugins-official` マーケットプレイスから `claude plugin install miro@claude-plugins-official`
2. **Slack plugin** — 同マーケットプレイスから `claude plugin install slack@claude-plugins-official`
3. **Cosense skill plugin** — `helpfeel/cosense-cli` マーケットプレイスを追加し `claude plugin install cosense-cli@cosense-cli`
4. **cosense CLI** — `npm install -g @helpfeel/cosense-cli`（skillの実行に必要な companion CLI）

Miro・Slack plugin はどちらもリモート MCP サーバー（`mcp.miro.com` / `mcp.slack.com`）に接続し、初回利用時にブラウザでの OAuth 認証が必要。Cosense CLI は `cosense login <origin>` で Personal Access Token または Service Account を対話的に設定する（詳細は kit内の `cosense` skill の `login.md` 手順書を参照）。

## ネットワーク

| 用途 | ドメイン |
|------|----------|
| マーケットプレイスの git clone / GitHub API | `github.com`, `api.github.com` |
| cosense CLI の npm install | `registry.npmjs.org` |
| Miro MCP plugin | `mcp.miro.com`, `miro.com`, `*.miro.com` |
| Slack MCP plugin | `mcp.slack.com`, `slack.com`, `*.slack.com` |
| Cosense (Scrapbox) API | `scrapbox.io`, `*.scrapbox.io` |

## 使い方

```bash
sbx run claude --kit /path/to/claude-documentation/
```

see: https://docs.docker.com/ai/sandboxes/customize/kits/
