# nakahararuu-claude-plugins

`nakahararuu/claude-plugins` マーケットプレイスを追加し、そこに収録されている plugin を全てインストールする mixin kit。

## インストール内容

1. `jq` が無ければインストール（marketplace.json のパース用）
2. `claude plugin marketplace add nakahararuu/claude-plugins` でマーケットプレイスを追加
3. 追加したマーケットプレイスのキャッシュ（`~/.claude/plugins/marketplaces/nakahararuu-claude-plugins/.claude-plugin/marketplace.json`）から plugin 名を `jq` で列挙し、1件ずつ `claude plugin install <name>@nakahararuu-claude-plugins` を実行

plugin 名をハードコードせず動的に列挙してインストールしているため、`nakahararuu/claude-plugins` 側に plugin が追加されてもこの kit を更新する必要はない。

## ネットワーク

| フェーズ | 用途 | ドメイン |
|------|------|----------|
| install | jq が無い場合の apt-get install（DHI ベースの Debian / DHI リポジトリ、旧 Ubuntu ベースのミラー、*-docker テンプレートが追加済みの Docker の apt リポジトリ） | `deb.debian.org`, `dhi.io`, `archive.ubuntu.com`, `security.ubuntu.com`, `ports.ubuntu.com`, `download.docker.com` |
| install | マーケットプレイスの git clone / GitHub API | `github.com`, `api.github.com` |
| runtime | plugin の更新（マーケットプレイスの git fetch） | `github.com`, `api.github.com` |

**注意:** ここで許可しているのはマーケットプレイス自体の取得に必要なドメインのみ。将来追加される plugin が npm パッケージや外部 API など追加のネットワークアクセスを必要とする場合は、`network-policy@1` の該当フェーズ（install 時の取得なら `install.allow`、実行時なら `runtime.allow`）を更新する必要がある。

## 使い方

```bash
sbx run docker.io/docker/sbx-kit-claude:2.1.311 --kit ghcr.io/nakahararuu/sbx-kits/nakahararuu-claude-plugins:latest .
```

see: https://docs.docker.com/ai/sandboxes/customize/
