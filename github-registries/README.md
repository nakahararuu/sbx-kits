# github-registries

GitHub Packages（npm）と GitHub Container Registry（ghcr.io）への接続時に、`GITHUB_TOKEN` を使った認証情報を自動的に注入する mixin kit。

## インストール内容

- `~/.npmrc` に `//npm.pkg.github.com/:_authToken=${GITHUB_TOKEN}` を追記
  （既存の `.npmrc` があれば末尾に追記、同じ行が既にあれば追記しない）
- `~/.docker/config.json` に `ghcr.io` 向けの `auth` エントリを追加
  （既存の `config.json` があれば `jq` でマージ、他レジストリの設定は保持）

これにより、サンドボックス内で追加のログイン操作なしに以下が動きます。

```bash
npm install @your-org/some-package   # npm.pkg.github.com がスコープ登録されていれば
docker pull ghcr.io/your-org/your-image:latest
docker push ghcr.io/your-org/your-image:latest
```

## 認証情報の流れ

このkitは `credentials` ブロックで `github` サービスの credential を宣言し、`npm.pkg.github.com` と `ghcr.io` への通信にプロキシ経由で注入されるよう設定します。

- サンドボックス内の `GITHUB_TOKEN` 環境変数は常にプレースホルダ文字列 `proxy-managed` です。実際のトークンはサンドボックス外のプロキシがネットワークリクエストの送信時に差し替えるため、**実トークンはサンドボックスのファイルシステムやプロセス一覧には一切現れません**。
- kit 自身は「トークンをどこから取得するか」を宣言しません（`sbx` の credential binding の設計上、kit は "何が必要か" だけを宣言し、"どこにあるか" はユーザー側の設定に委ねられています）。

### ホスト側の設定（ユーザーが1回だけ実行）

ホストの環境変数 `GITHUB_TOKEN` から読み取ってグローバルなsecretとして保存するのが最も簡単です。

```bash
sbx secret set -g github -t "$GITHUB_TOKEN"
```

これでこの kit を使うすべてのサンドボックスで `github` credential が解決されます。特定のサンドボックスだけに設定したい場合は `-g` を外して `sbx secret set <sandbox名> github -t "$GITHUB_TOKEN"` を使ってください。

`sbx secret set` を使わない場合、初回 `sbx run`/`sbx kit add` 時に対話的な承認フローが走り、`GITHUB_TOKEN` 環境変数を読みに行くバインディングを `~/.config/sbx/credentials.yaml` に保存するかどうかを聞かれます。詳細は [`sbx-kits-contrib` の credential bindings ドキュメント](https://github.com/docker/sbx-kits-contrib/blob/main/skills/kit-author/topics/bindings.md) を参照してください。

## ネットワーク

| 用途 | ドメイン | 認証情報の注入 |
|------|----------|----------------|
| GitHub Packages (npm) | `npm.pkg.github.com` | あり（Bearer） |
| GitHub Container Registry | `ghcr.io` | あり（Basic, username: `x-access-token`） |
| GHCR のイメージレイヤー転送先 | `pkg-containers.githubusercontent.com` | なし（到達性のみ許可） |

## 対応していないGitHub Packagesのエコシステム

npm と コンテナ（ghcr.io）のみ対応しています。Maven / NuGet / RubyGems などが必要な場合は、`spec.yaml` の `caps.network.allow` と `credentials[0].apiKey.inject` に該当ホスト（例: `maven.pkg.github.com`）を追加し、`commands.install` にその形式の設定ファイル（`~/.m2/settings.xml` など）を書き出すシェルコマンドを追加してください。`commands.initFiles` の `content` は `${WORKDIR}` 以外のプレースホルダを受け付けないため、`${GITHUB_TOKEN}` を埋め込むファイルは必ず `commands.install` のシェルコマンドで書き出す必要があります（本 kit の `.npmrc`/`config.json` の実装を参照）。

## 使い方

```bash
sbx run claude --kit /path/to/github-registries/
```

または既存サンドボックスに追加:

```bash
sbx kit add <sandbox名> /path/to/github-registries/
```
