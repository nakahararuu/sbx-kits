# nakahararuu-claude-plugins

`nakahararuu/claude-plugins` マーケットプレイスを追加し、そこに収録されている plugin を全てインストールする mixin kit。

## インストール内容

1. `jq` が無ければインストール（marketplace.json のパース用）
2. `claude plugin marketplace add nakahararuu/claude-plugins` でマーケットプレイスを追加
3. 追加したマーケットプレイスのキャッシュ（`~/.claude/plugins/marketplaces/nakahararuu-claude-plugins/.claude-plugin/marketplace.json`）から plugin 名を `jq` で列挙し、1件ずつ `claude plugin install <name>@nakahararuu-claude-plugins` を実行

plugin 名をハードコードせず動的に列挙してインストールしているため、`nakahararuu/claude-plugins` 側に plugin が追加されてもこの kit を更新する必要はない。

## ネットワーク

| 用途 | ドメイン |
|------|----------|
| マーケットプレイスの git clone | `github.com` |
| GitHub API アクセス | `api.github.com` |

**注意:** ここで許可しているのはマーケットプレイス自体の取得に必要なドメインのみ。将来追加される plugin が npm パッケージや外部 API など追加のネットワークアクセスを必要とする場合は、この `network.allowedDomains` を更新する必要がある。

## 使い方

```bash
sbx run claude --kit /path/to/nakahararuu-claude-plugins/
```

see: https://docs.docker.com/ai/sandboxes/customize/kits/
