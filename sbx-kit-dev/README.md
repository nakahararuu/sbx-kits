# sbx-kit-dev

このリポジトリで kit を開発する際に `sbx` CLI を使えるようにする mixin kit。

## インストール内容

- **sbx CLI** — `docker/sbx-releases` の最新リリースから、実行アーキテクチャ（x86_64/arm64）に対応する `DockerSandboxes-linux-*.tar.gz` をダウンロードし、中身の `docker-sbx/sbx` バイナリだけを `/usr/local/bin/sbx` に配置する

`sbx` は静的バイナリで、daemon や VM (KVM等) を必要としないサブコマンドは通常のサンドボックス環境内でもそのまま動く（`sbx run` 等サンドボックス自体を作成するコマンドはこの kit の対象外）。

## agent-context

このリポジトリの kit は kit-spec v3（`<kit>/<kit>.yaml`、先頭行 `# syntax=docker/sandbox-kit:3`）で書かれている。`sbx kit validate` は v3 のソース kit を扱えないため、kit を編集したら次のように kit frontend でビルドして検証するよう agent に指示を注入する。

```bash
docker buildx build <kit-dir> -f <kit-dir>/<kit>.yaml --output type=cacheonly
```

v3 は strict decoding なので、v2 の名残（`name:` や `permissions:` など）や置き場所を間違えたフィールドはここで行番号付きのエラーになる。

## ネットワーク

| フェーズ | 用途 | ドメイン |
|------|------|----------|
| install | 最新リリースAPI・アセットダウンロード | `api.github.com`, `github.com`, `objects.githubusercontent.com`, `release-assets.githubusercontent.com` |

## 使い方

```bash
sbx run docker.io/docker/sbx-kit-claude:2.1.267 --kit "git+https://github.com/nakahararuu/sbx-kits.git#dir=sbx-kit-dev" .
```

see: https://docs.docker.com/ai/sandboxes/customize/
