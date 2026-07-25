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
