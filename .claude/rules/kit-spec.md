---
description: Where to find sbx kit documentation when editing spec.yaml
globs: ["**/spec.yaml"]
alwaysApply: false
---

# Kit 仕様の情報源

`spec.yaml` を編集する際は、以下の情報源を参照してください。

## 公式ドキュメント

Docker Sandboxes の kit 仕様は公式ドキュメントに記載されています：

- Kit の概要・種類（mixin/sandbox）・フィールド一覧: https://docs.docker.com/ai/sandboxes/customize/kits/

## context7 MCP サーバ

このプロジェクトには context7 MCP サーバが設定されています。Docker ドキュメントのライブラリとして登録されており、kit に関する情報も取得できます。

```
# ライブラリ ID の解決
mcp__plugin_context7_context7__resolve-library-id: "docker sandboxes"

# ドキュメント取得
mcp__plugin_context7_context7__query-docs: "kit spec.yaml fields"
```

公式ドキュメントの URL が手元にない場合や、特定のフィールドについて素早く確認したい場合に有効です。

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

kit を作成したら、`commands.install` を実行してエラーなく完了するかで allowlist の過不足に気づけます。通信が拒否されるとインストールコマンドがエラーで失敗するため、エラーメッセージに出てくるホスト名を allowlist に追記して再検証してください。

参考実装: `datadog-claude/spec.yaml`、`claude-documentation/spec.yaml`、`nakahararuu-claude-plugins/spec.yaml` の `network.allowedDomains` を参照。
