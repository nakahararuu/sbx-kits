# github-registries

GitHub Packages（npm・Maven/Gradle）と GitHub Container Registry（ghcr.io）への接続時に、GitHub のトークンを使った認証情報を自動的に注入する mixin kit。

## インストール内容

`npm.pkg.github.com`・`maven.pkg.github.com`・`ghcr.io` 宛の通信に認証情報を注入するよう `credentials`/`caps.network` を設定するだけです。`.npmrc`・`.docker/config.json`・`.m2/settings.xml` などのローカル設定ファイルはこの kit では一切書き込みません。

このkitの責務は「ログインしようとした時に認証情報を差し替える」ことだけです。GitHub Packages/GHCR を使うプロジェクトは、`.npmrc`・`docker login`・`settings.xml` の `<server>` エントリなど、認証ヘッダ付きリクエストを送る仕組みをすでに用意しているはずという前提に立っています。プロジェクト側でログインステップ（`docker login` など）が必要な場合は、この kit を入れても引き続きそのステップの実行が必要です — kit が変えるのは、そこに渡す値が実トークンでなくてよくなる、という点だけです。

```bash
npm install @your-org/some-package   # プロジェクトの .npmrc が npm.pkg.github.com を参照していれば
docker pull ghcr.io/your-org/your-image:latest
docker push ghcr.io/your-org/your-image:latest
mvn deploy   # プロジェクトの settings.xml に <server><id>github</id> があれば
```

## 認証情報の流れ

`npm.pkg.github.com` は Bearer トークンで認証しますが、`maven.pkg.github.com` と `ghcr.io` は Basic 認証で、`git` の HTTPS クローンのようにユーザー名を任意の文字列（例: `x-access-token`）で済ませることができません。実在するユーザー名が必要です。

`sbx` の credential は1つの値しか運べず、ユーザー名とパスワードの組を別々には扱えないため、この kit では2つの credential を宣言しています。

| service | 環境変数 | 注入先 | 値 |
|---------|----------|--------|-----|
| `github` | `GITHUB_TOKEN` | `npm.pkg.github.com`（Bearer） | 生の GitHub トークン |
| `github-basic` | `GITHUB_BASIC_AUTH` | `maven.pkg.github.com` / `ghcr.io`（Basic） | `base64("ユーザー名:トークン")` を事前に結合した値 |

`github-basic` はホスト側で以下のようにユーザー名とトークンを連結・Base64エンコードしてから登録してください。

```bash
sbx secret set -g github -t "$GITHUB_TOKEN"
sbx secret set -g github-basic -t "$(printf '%s:%s' "<GitHubユーザー名>" "$GITHUB_TOKEN" | base64 -w0)"
```

- サンドボックス内の `GITHUB_TOKEN`/`GITHUB_BASIC_AUTH` 環境変数は常にプレースホルダ文字列 `proxy-managed` です。実際の値はサンドボックス外のプロキシがネットワークリクエストの送信時に差し替えるため、**実際の認証情報はサンドボックスのファイルシステムやプロセス一覧には一切現れません**。
- kit 自身は「credentialの値をどこから取得するか」を宣言しません（`sbx` の credential binding の設計上、kit は "何が必要か" だけを宣言し、"どこにあるか" はユーザー側の設定に委ねられています）。

これでこの kit を使うすべてのサンドボックスで両方の credential が解決されます。特定のサンドボックスだけに設定したい場合は `-g` を外して `sbx secret set <sandbox名> <service> -t "<値>"` を使ってください。

`sbx secret set` を使わない場合、初回 `sbx run`/`sbx kit add` 時に対話的な承認フローが走り、環境変数を読みに行くバインディングを `~/.config/sbx/credentials.yaml` に保存するかどうかを聞かれます。詳細は [`sbx-kits-contrib` の credential bindings ドキュメント](https://github.com/docker/sbx-kits-contrib/blob/main/skills/kit-author/topics/bindings.md) を参照してください。

## ネットワーク

| 用途 | ドメイン | 認証情報の注入 |
|------|----------|----------------|
| GitHub Packages (npm) | `npm.pkg.github.com` | あり（Bearer, `github`） |
| GitHub Packages (Maven/Gradle) | `maven.pkg.github.com` | あり（Basic, `github-basic`） |
| GitHub Container Registry | `ghcr.io` | あり（Basic, `github-basic`） |
| GHCR のイメージレイヤー転送先 | `pkg-containers.githubusercontent.com` | なし（到達性のみ許可） |

## 対応していないGitHub Packagesのエコシステム

npm・Maven/Gradle・コンテナ（ghcr.io）のみ対応しています。NuGet / RubyGems などが必要な場合は、`spec.yaml` の `caps.network.allow` に該当ホスト（例: `nuget.pkg.github.com`）を追加し、認証方式に応じて `credentials[].apiKey.inject` に追加してください（Bearerなら `github` に、実ユーザー名が必要なBasicなら `github-basic` に追記）。

## 使い方

```bash
sbx run claude --kit /path/to/github-registries/
```

または既存サンドボックスに追加:

```bash
sbx kit add <sandbox名> /path/to/github-registries/
```
