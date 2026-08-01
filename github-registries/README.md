# github-registries

GitHub Packages（npm・Maven/Gradle）と GitHub Container Registry（ghcr.io）への接続時に、`GITHUB_TOKEN` を使った認証情報を自動的に注入する mixin kit。

## インストール内容

- `npm.pkg.github.com`・`maven.pkg.github.com`・`ghcr.io` 宛の通信に `GITHUB_TOKEN` を注入するよう `credentials`/`caps.network` を設定
- `~/.m2/settings.xml` に `id: github` の `<server>` エントリを設定
  （GitHub公式のMaven/Gradleドキュメントが `pom.xml`/`build.gradle` 側で指定するように案内している `id` と一致。`files/home/.m2/settings.xml` として静的ファイルで配置するため、既存の `settings.xml` があれば上書き）

`.npmrc` や `.docker/config.json` はこの kit では書き込みません。npm/Docker には、GitHub Packages/GHCR を使うために必要な `${GITHUB_TOKEN}` 参照付きの `.npmrc`／`docker login` のような、プロジェクト側で通常すでに用意されているはずの仕組みに乗る前提です（Mavenだけは同等の環境変数駆動の慣習が無いため、この kit が `settings.xml` を用意します）。この kit が用意するのは、その仕組みが実際に認証ヘッダを送った時に載せる実トークンの部分だけです。

セットアップ済みのプロジェクトでは、サンドボックス内で追加のログイン操作なしに以下が動きます。

```bash
npm install @your-org/some-package   # プロジェクトの .npmrc が npm.pkg.github.com を参照していれば
docker pull ghcr.io/your-org/your-image:latest
docker push ghcr.io/your-org/your-image:latest
mvn deploy   # pom.xml の <repository><id>github</id> と対応
```

## 認証情報の流れ

このkitは `credentials` ブロックで `github` サービスの credential を宣言し、`npm.pkg.github.com` / `maven.pkg.github.com` / `ghcr.io` への通信にプロキシ経由で注入されるよう設定します。

- サンドボックス内の `GITHUB_TOKEN` 環境変数は常にプレースホルダ文字列 `proxy-managed` です。実際のトークンはサンドボックス外のプロキシがネットワークリクエストの送信時に差し替えるため、**実トークンはサンドボックスのファイルシステムやプロセス一覧には一切現れません**。
- kit 自身は「トークンをどこから取得するか」を宣言しません（`sbx` の credential binding の設計上、kit は "何が必要か" だけを宣言し、"どこにあるか" はユーザー側の設定に委ねられています）。

### ホスト側の設定(ユーザーが1回だけ実行)

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
| GitHub Packages (Maven/Gradle) | `maven.pkg.github.com` | あり（Basic, username: `x-access-token`） |
| GitHub Container Registry | `ghcr.io` | あり（Basic, username: `x-access-token`） |
| GHCR のイメージレイヤー転送先 | `pkg-containers.githubusercontent.com` | なし（到達性のみ許可） |

## 対応していないGitHub Packagesのエコシステム

npm・Maven/Gradle・コンテナ（ghcr.io）のみ対応しています。NuGet / RubyGems などが必要な場合は、`spec.yaml` の `caps.network.allow` と `credentials[0].apiKey.inject` に該当ホスト（例: `nuget.pkg.github.com`）を追加してください。ローカル設定ファイルは、そのエコシステムに環境変数駆動の慣習が無い場合（本kitのMavenのように）だけ追加すれば十分です。`files/home/...` 配下の静的ファイルにするのがおすすめです（[spec §5.8](https://github.com/docker/sbx-kits-contrib/blob/main/spec/SPEC-v2.md#58-files-directory)）。`${GITHUB_TOKEN}` のようなプレースホルダも静的ファイルにそのまま書けます（sbxではなく、それを読むツール側が自分のタイミングで展開するため）。`commands.initFiles` の `content` は `${WORKDIR}` 以外のプレースホルダを受け付けないため、`${GITHUB_TOKEN}` を埋め込むファイルは `commands.initFiles` では書けません。

## 使い方

```bash
sbx run claude --kit /path/to/github-registries/
```

または既存サンドボックスに追加:

```bash
sbx kit add <sandbox名> /path/to/github-registries/
```
