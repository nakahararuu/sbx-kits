# sbx-kit-dev

このリポジトリで kit を開発する際に `sbx` CLI を使えるようにする mixin kit。

## インストール内容

- **sbx CLI** — `docker/sbx-releases` の最新リリースから、実行アーキテクチャ（x86_64/arm64）に対応する `DockerSandboxes-linux-*.tar.gz` をダウンロードし、中身の `docker-sbx/sbx` バイナリだけを `/usr/local/bin/sbx` に配置する

`sbx` は静的バイナリで、`sbx kit validate` / `sbx kit inspect` / `sbx kit pack` などのサブコマンドは daemon や VM (KVM等) を必要としないため、通常のサンドボックス環境内でもそのまま動く（`sbx run` 等サンドボックス自体を作成するコマンドはこの kit の対象外）。

## agentContext

`spec.yaml` を編集した後は必ず `sbx kit validate <kit-dir>` を実行するよう、agent memory に指示を注入する。deprecated fieldの警告（例: kit-spec v2 での `network.allowedDomains` → `caps.network.allow` 移行）はファイルを読むだけでは気づきにくいため。

なお、このリポジトリ自体には `.claude/settings.json` に `PostToolUse` hook（`.claude/hooks/validate-kit-spec.sh`）を設定済みで、`spec.yaml` の Edit/Write 後に自動で `sbx kit validate` が走り、失敗時はagentにフィードバックされる。この kit の agentContext は、hookが無い他のリポジトリ/kit開発環境向けの保険。

## ネットワーク

| 用途 | ドメイン |
|------|----------|
| 最新リリースAPI・アセットダウンロード | `api.github.com`, `github.com`, `objects.githubusercontent.com` |

## 使い方

```bash
sbx run claude --kit /path/to/sbx-kit-dev/
```

see: https://docs.docker.com/ai/sandboxes/customize/kits/
