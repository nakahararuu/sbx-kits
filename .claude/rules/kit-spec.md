---
description: Where to find sbx kit (kit-spec v3) documentation and known pitfalls when editing kits
globs: ["*/*.yaml", "*/*.dockerfile", "*/*-context.md"]
alwaysApply: false
---

# Kit 仕様の情報源（kit-spec v3）

このリポジトリの kit はすべて **kit-spec v3** で書かれています。v2（`spec.yaml`、`permissions`、`setup`、`agentInstructions`）の知識で書くと strict decode で落ちるので、以下の情報源を参照してください。新規作成・移行の手順は `.claude/skills/kit-v3-author/SKILL.md` にまとめてあります。

## 公式ドキュメント

- 仕様本体: https://github.com/docker/sandbox-kit-spec/blob/main/docs/spec/SPEC-v3.md
- capability ごとの仕様: https://github.com/docker/sandbox-kit-spec/tree/main/docs/spec/capabilities/com.docker.sandbox
- v2→v3 のフィールド対応表: https://github.com/docker/sandbox-kit-spec/blob/main/skills/migrate-kit-to-v3/FIELD-MAPPING.md
- ユーザーマニュアル: https://docs.docker.com/ai/sandboxes/customize/ （author / tool-mixins / patterns / capabilities / kit-sets / distribute）
- 実例: docker/sbx-kits-contrib の **`v3` ブランチ**（main ブランチは v2 のままなので参照しないこと）

仕様（SPEC-v3.md）と docs.docker.com が食い違う場合は、実際に使う `sbx` がサポートしている方（docs の capability 対応表）に合わせる。例: agent-context は `@2` もあるが、docs と contrib v3 は `@1` を使っているのでこのリポジトリも `@1`。

## ファイル構成

```text
<kit>/
├── <kit>.yaml          # 記述子。1行目は必ず `# syntax=docker/sandbox-kit:3`
├── <kit>.dockerfile    # 任意。イメージに焼き込む内容（ファイル名の stem で自動検出）
├── <kit>-context.md    # 任意。agent-context@1 の contentFile
└── README.md
```

- ディレクトリ名と記述子のファイル名は一致させる（CI と `.claude/hooks/validate-kit-spec.sh` はこの規約で kit を見つける）。
- mixin は `.dockerfile` が無くてもよい（宣言だけの kit になる）。

## 検証方法

`sbx kit validate` は v3 のソース kit を扱えない。kit frontend でビルドして検証する:

```bash
docker buildx build <kit> -f <kit>/<kit>.yaml --output type=cacheonly
```

kit ディレクトリ内のファイルを Edit/Write すると PostToolUse hook が自動でこれを実行し、失敗時は agent にフィードバックされる。CI（`.github/workflows/validate-kits.yml`）も同じコマンドで全 kit を検証している。

ビルドが通っても、ネットワークや hook の挙動は実際のサンドボックスでしか確かめられない。動作確認は v3 workload と一緒に新規サンドボックスを作って行う（`sbx kit add` は既存の v3 サンドボックスに mixin を追加できないので作り直す）:

```bash
sbx run docker.io/docker/sbx-kit-claude:<tag> --kit ./<kit> .
```

## 落とし穴: v3 の書き方

### 1. strict decode — v2 のフィールドが1つでも残ると失敗する

トップレベルの `name:` は廃止（kit の識別子は参照 URL/イメージ名）。`permissions` / `setup` / `agentInstructions` / `credentials` はすべて `capabilities:` 配下の capability に置き換わる。キーは lowerCamelCase（`sourceUrl`、`apiKey`）。

### 2. hook の環境変数は deny-by-default

`lifecycle@1` の hook には `PATH` / `HOME` などの最低限しか渡らない。hook 本体や子プロセスが読む変数はすべてその hook の `env: [...]` に列挙する。特に **curl / npm / pip / uv / apt / `claude plugin install` などネットワークに出るコマンドはプロキシ変数が必要**なので `env: [HTTP_PROXY, HTTPS_PROXY, NO_PROXY]` を付ける。ワークスペースのパスは `env: [WORKSPACE_DIR]`（`files` の中なら `${{ kit.env.WORKSPACE_DIR }}`）。

### 3. `background: true` は startup hook 専用

install hook に `background` を書くと strict decode で落ちる。

### 4. v2 の `files/` 自動コピーは無い

v2 では `files/home/`・`files/workspace/` が自動でコピーされたが、v3 では `files/` はただのビルドコンテキスト。ホーム配下は `.dockerfile` で `COPY` する。ワークスペースに置くファイルは `lifecycle@1` の `files` に `path: "${{ kit.env.WORKSPACE_DIR }}/..."` で書く（参考: `sample-ruff-lint`）。

### 5. install hook は「焼き込めないか」を先に考える

v3 の mixin はイメージ（overlay）を持てる。ダウンロードして置くだけのバイナリは `.dockerfile` に移すと、サンドボックス作成時のネットワーク許可も要らなくなる。hook に残すべきなのは、`apt-get`（mixin は apt パッケージを overlay で運べない）、`claude plugin install` のようにベースのファイルへマージするもの、作成時の値や Docker デーモンが必要なもの。

### 6. v3 サンドボックスでは全 kit が v3

組み込みの `claude` エージェント名は v2 kit 用。v3 kit は `docker.io/docker/sbx-kit-claude` などの v3 workload と組み合わせる。docker/sbx-kits-contrib の kit は `#ref=v3&dir=<kit>` で v3 ブランチを参照する。

## 落とし穴: network policy

sandbox はデフォルトで送信通信を deny するため、kit が動かすツールが通信する先はすべて `com.docker.sandbox/network-policy@1` に明記する必要があります。v3 ではフェーズごとに分けて書きます。

```yaml
- type: com.docker.sandbox/network-policy@1
  config:
    install:          # install hook 実行中だけ開く
      allow: [registry.npmjs.org]
    runtime:          # エージェント実行中と startup hook
      allow: [api.example.com, "*.example.com"]
      deny: [telemetry.example.com]
```

### 1. 「インストール時」と「実行時」の両方のホストを洗い出し、フェーズに振り分ける

- **install**: install hook が触るホスト（パッケージレジストリ、リリース配布元、`claude plugin marketplace add` の GitHub）
- **runtime**: ツール本体が使う API（例: `*.datadoghq.com`）、**startup hook が触るホスト**（startup は runtime フェーズで動く）、実行中のプラグイン更新や `npx`/`uvx` での取得
- 両方で使うホストは両方に書く。書かなかったフェーズでは何も許可されない。
- `*.example.com` はサブドメイン1階層だけにマッチし、`example.com` 自体にはマッチしない。

### 2. GitHub からのインストールは `github.com` だけでは足りない

`gh`/`curl` 経由で GitHub Releases のバイナリを取得する場合、リダイレクト先は `github.com` とは別ドメインです。

- `api.github.com`（Releases API 呼び出し）
- `github.com`（リポジトリ自体へのアクセス）
- `objects.githubusercontent.com` / `release-assets.githubusercontent.com`（Release アセットの実ダウンロード先）

### 3. Claude plugin マーケットプレイスも GitHub 経由

`claude plugin marketplace add` / `claude plugin install` は内部で GitHub 上のマーケットプレイスリポジトリを取得するため、install フェーズに GitHub 系ドメインが必要です。実行中のプラグイン更新のために runtime にも入れておく。

### 4. `apt-get` には apt ミラーの許可が要る

`apt-get update` は設定済みの全ソースを更新するので、Ubuntu の `archive.ubuntu.com` / `security.ubuntu.com`（amd64）、`ports.ubuntu.com`（arm64）、`download.docker.com`（*-docker テンプレートが追加済み）を install フェーズに入れる（参考: `chrome-devtools-host`）。

### 5. 動作確認の方法

network policy はサンドボックス内のプロキシが強制するものなので、hook のコマンドをサンドボックスの外でそのまま実行しても検証にはなりません。かならず kit を実際にサンドボックスへ適用して確認してください。許可が足りないドメインへの通信は HTTP 403 で拒否されます。ホスト側で `sbx policy log` を見るか、サンドボックス内の `/var/log/sbx-kit-startup.log` を確認し、出てきたホスト名を該当フェーズに追記してサンドボックスを作り直してください。

参考実装: `datadog-claude/datadog-claude.yaml`、`claude-documentation/claude-documentation.yaml`、`langfuse-claude/langfuse-claude.yaml`。

## 落とし穴: credentials（トークン注入）

APIキーやトークンをコンテナ内に注入する kit は `com.docker.sandbox/credential@1` を (service, phase) ごとに1つ書きます。

### 1. kit は「何が必要か」だけを宣言する。「どこにあるか」は書かない

```yaml
- type: com.docker.sandbox/credential@1
  optional: true          # v3 は既定で必須。v2 と同じく任意にするなら明示する
  config:
    service: github
    phase: runtime        # [install, runtime] も可
    apiKey:
      name: GITHUB_TOKEN
      proxyManaged: true
      inject:
        - domain: npm.pkg.github.com
          header: Authorization
          format: "Bearer %s"
```

実トークンをどのホスト環境変数・ファイルから読むかは kit に書けません。「ホストの環境変数 `FOO_TOKEN` から取る」という要件は README で `sbx secret set -g <service> -t "$FOO_TOKEN"` を案内する形に落とし込む（`sbxenv.yaml` の `secrets` / `bindings` で解決することもできる）。

### 2. `inject[].domain` は同じフェーズの allow に完全一致で入れる

`*.example.com` を allow していても `api.example.com` への inject は検証で落ちる。ワイルドカードの横に完全一致のホストを書き足す。

### 3. コンテナ内のトークン環境変数は実値ではない

`apiKey.proxyManaged: true` を設定すると、コンテナ内の該当環境変数には常にリテラル文字列 `proxy-managed` が入ります。実トークンはサンドボックス外のプロキシが、宣言した `inject[].domain` 宛のリクエストを流す瞬間に差し替える。トークンを埋め込む設定ファイル（`.npmrc` など）は `${GITHUB_TOKEN}` のようなプレースホルダを書いておき、ツール自身に実行時展開させる。

### 4. `lifecycle@1` の `files` で展開されるのは `${{ kit.* }}` だけ

`${GITHUB_TOKEN}` のようなシェル変数は展開されずにそのまま書かれる（ツール側で展開させたいならそれで良い）。hook の中で値を使う場合は `env:` に列挙する。
