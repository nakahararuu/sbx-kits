# sbx-kit-dev

このリポジトリの kit（kit-spec v3）をサンドボックスの中で開発・検証できるようにする mixin kit。

## 何をするか

v3 のソース kit は `sbx kit validate` では検証できず、kit frontend でビルドして検証します。

```bash
docker buildx build <kit-dir> -f <kit-dir>/<kit>.yaml --output type=cacheonly
```

このコマンドには、サンドボックス内の Docker Engine と buildx プラグイン、および Docker Hub（kit frontend のイメージ `docker/sandbox-kit:3` の取得元）への通信が必要です。この kit はそれを次のように揃えます。

- **Docker Engine / buildx** — 自分ではインストールせず、workload が提供していることを `requires: ["deb/docker-ce", "deb/docker-buildx-plugin"]` で宣言する。`docker.io/docker/sbx-kit-claude` はどちらも提供しているので、そのまま組み合わせられる（提供していない workload と組み合わせるとサンドボックス作成時にエラーになる）
- **Docker Hub への通信** — workload のネットワークポリシーには含まれていないので、runtime フェーズで許可する
- **agent-context** — kit を編集したら上記のコマンドで検証すること、ビルドが通っても通信許可や hook の動作は実際のサンドボックスでしか確認できないことを agent に伝える

v2 の頃は `sbx kit validate` のために sbx CLI をインストールしていたが、v3 では検証に使えないためインストールをやめた。

なお、このリポジトリ自体には `.claude/settings.json` に `PostToolUse` hook（`.claude/hooks/validate-kit-spec.sh`）を設定してあり、kit の編集後に自動で検証が走る。この kit の agent-context は、hook が効かない環境向けの保険。

## ネットワーク

| フェーズ | 用途 | ドメイン |
|------|------|----------|
| runtime | kit frontend・ベースイメージの取得（Docker Hub） | `registry-1.docker.io`, `auth.docker.io`, `production.cloudflare.docker.com` |

kit の `<kit>.dockerfile` が `RUN` で他のホストからダウンロードする場合、そのホストは許可されていないため、ビルドが失敗することがあります。必要に応じてサンドボックス側のポリシーで許可してください。

## 使い方

```bash
sbx run docker.io/docker/sbx-kit-claude:2.1.267 --kit "git+https://github.com/nakahararuu/sbx-kits.git#dir=sbx-kit-dev" .
```

see: https://docs.docker.com/ai/sandboxes/customize/
