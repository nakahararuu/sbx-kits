---
description: Where to find sbx kit documentation when editing spec.yaml
globs: ["**/spec.yaml"]
alwaysApply: false
---

# Kit 仕様の情報源

`spec.yaml` を編集する際は、以下の情報源を参照してください。

## 公式ドキュメント

Docker Sandboxes の kit 仕様は公式ドキュメントに記載されています：

- Kit の概要・種類（mixin/sandbox）・フィールド一覧: https://github.com/docker/sbx-kits-contrib/blob/main/spec/SPEC-v2.md

## 落とし穴: network policy

sandbox はデフォルトで送信通信を deny するため、kit が動かすツールが通信する先はすべて `network.allowedDomains` に明記する必要があります。公式ドキュメントには載っていないが、実際の kit 作成で頻繁にハマるポイントを以下にまとめます。

### 1. 「インストール時」と「実行時」の両方のホストを洗い出す

kit がツールをインストールしてから実際に使うまでに、通信先が変わることが多いです。両方を allowlist に入れる必要があります。

- **実行時の通信先**: ツール本体が使う API（例: `datadoghq.com`, `*.datadoghq.com`）
- **インストール時の通信先**: パッケージレジストリやリリース配布元（例: `registry.npmjs.org`, `pypi.org`）

### 2. GitHub からのインストールは `github.com` だけでは足りない

`gh`/`curl` 経由で GitHub Releases のバイナリを取得する場合、リダイレクト先は `github.com` とは別ドメインです。以下も allow しておく必要があります。

- `api.github.com`（Releases API 呼び出し）
- `github.com`（リポジトリ自体へのアクセス）
- `objects.githubusercontent.com`（Release アセットの実ダウンロード先）

### 3. Claude plugin マーケットプレイスも GitHub 経由

`claude plugin marketplace add` / `claude plugin install` は内部で GitHub 上のマーケットプレイスリポジトリを取得するため、上記 GitHub 系ドメインの allow が必要です。

### 4. 動作確認の方法

network policy はサンドボックス内のプロキシが強制するものなので、`commands.install` に書いたコマンドをサンドボックスの外（手元のシェルなど）でそのまま実行しても検証にはなりません。かならず kit を実際にサンドボックスへ適用して確認してください。

```bash
sbx run <agent> --kit /path/to/kit/   # 新規サンドボックスを作成して kit を適用
sbx kit add <sandbox名> /path/to/kit/ # 既存サンドボックスに kit を追加
```

allowlist が不足しているドメインへの通信は、サンドボックス内で `commands.install` 実行中に HTTP 403 で拒否されます。エラーメッセージに出てくるホスト名を `network.allowedDomains` に追記し、`sbx kit add` などで再適用して再検証してください。

参考実装: `datadog-claude/spec.yaml`、`claude-documentation/spec.yaml`、`nakahararuu-claude-plugins/spec.yaml` の `network.allowedDomains` を参照。
