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

### 5. `claude plugin marketplace add owner/repo` の省略記法は SSH に解決されることがある

`claude plugin marketplace add owner/repo` の `owner/repo` 省略記法は、内部で GitHub をどのプロトコル（HTTPS/SSH）で clone するかが公式ドキュメントに明記されておらず、`sbx run` を実行するホストマシンの git 設定（`url.insteadOf` の書き換えルールなど）によって SSH 経由の clone に解決されることがある。サンドボックスは SSH 用の `known_hosts` を持たない使い捨てコンテナなので、この場合 `commands.install` 実行中に `ssh host key is not in your known_hosts` のようなエラーで失敗する。マシンによって成功・失敗が分かれるのはこれが原因。

回避策は、省略記法ではなく `.git` サフィックス付きの HTTPS フル URL を明示すること。これで常に HTTPS 経由になり、SSH には解決されなくなる。

```bash
# NG: ホストの git 設定次第で SSH に化けることがある
claude plugin marketplace add nakahararuu/claude-plugins

# OK: HTTPS を明示（.git サフィックス必須。無いと marketplace.json への直リンクとして解釈される）
claude plugin marketplace add https://github.com/nakahararuu/claude-plugins.git
```

マーケットプレイス名は clone に使った URL ではなく `marketplace.json` 内の `name` フィールドで決まるため、`owner/repo` 省略記法から HTTPS フル URL に変更しても `claude plugin install <plugin>@<marketplace-name>` 側の参照名は変わらない。

参考実装: `nakahararuu-claude-plugins/spec.yaml`。

## 落とし穴: credentials（トークン注入）

APIキーやトークンをコンテナ内に注入する kit を作るときの設計:

### 1. kit は「何が必要か」だけを宣言する。「どこにあるか」は書かない

`credentials` ブロックは以下のように、サービス名・注入先ドメイン・スキームだけを宣言します。実トークンをどのホスト環境変数・ファイルから読むかは kit に書けません。解決の仕組み（bindings / `sbx secret set`）は https://github.com/docker/sbx-kits-contrib/blob/main/skills/kit-author/topics/bindings.md を参照してください。

```yaml
credentials:
  - service: github
    apiKey:
      name: GITHUB_TOKEN
      proxyManaged: true
      inject:
        - domain: npm.pkg.github.com
          scheme: bearer
```

「ホストの環境変数 `FOO_TOKEN` から取る」という要件は、kit の `spec.yaml` にはロジックが書けないので、README で `sbx secret set -g <service> -t "$FOO_TOKEN"` を案内する形に落とし込む。

### 2. コンテナ内のトークン環境変数は実値ではない

`apiKey.proxyManaged: true` を設定すると、コンテナ内の該当環境変数（例 `GITHUB_TOKEN`）には常にリテラル文字列 `proxy-managed` が入ります。実トークンはサンドボックス外のプロキシが、宣言した `inject[].domain` 宛のリクエストを流す瞬間に差し替えるため、コンテナのファイルシステムやプロセス一覧には一切現れません。トークンを埋め込む設定ファイル（`.npmrc` など）は、`${GITHUB_TOKEN}` のようなプレースホルダを書いておいて、ツール自身（npm 等）に実行時展開させる前提で作る。

### 3. `commands.initFiles` の `content` は `${WORKDIR}` 以外のプレースホルダを受け付けない

`${GITHUB_TOKEN}` のようなトークン用プレースホルダを埋め込んだファイルを `commands.initFiles` で書こうとすると、`sbx kit validate` で `unsupported placeholder` エラーになります。トークンを含むファイルは `commands.install` のシェルコマンド（`cat`/`echo`/`jq` など）で書き出すこと。

参考実装: `github-registries/spec.yaml`。
