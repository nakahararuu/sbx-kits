---
paths:
  - "*/*.yaml"
  - "*/*.dockerfile"
  - "*/*-context.md"
  - "*/files/**"
---

# Kit の書き方（kit-spec v3）

このリポジトリの kit はすべて **kit-spec v3** の mixin です。kit の新規作成・修正のときはこのファイルに従ってください。

## 情報源

- 仕様本体: https://github.com/docker/sandbox-kit-spec/blob/main/docs/spec/SPEC-v3.md
- capability ごとの仕様: https://github.com/docker/sandbox-kit-spec/tree/main/docs/spec/capabilities/com.docker.sandbox
- イメージ（overlay）の作り方: https://github.com/docker/sandbox-kit-spec/blob/main/skills/create-kit-v3/RECIPES.md
- ユーザーマニュアル: https://docs.docker.com/ai/sandboxes/customize/ （author / tool-mixins / patterns / capabilities / kit-sets / distribute）
- 実例: docker/sbx-kits-contrib の **`v3` ブランチ**（v3 の kit は main ではなくこのブランチにある）

仕様（SPEC-v3.md）と docs.docker.com が食い違う場合は、実際に使う `sbx` がサポートしている方（docs の capability 対応表）に合わせる。例: agent-context は `@2` もあるが、docs と contrib v3 は `@1` を使っているのでこのリポジトリも `@1`。

## ファイル構成と雛形

```text
<kit>/
├── <kit>.yaml          # 記述子。1行目は必ず `# syntax=docker/sandbox-kit:3`
├── <kit>.dockerfile    # 任意。イメージに焼き込む内容（ファイル名の stem で自動検出）
├── <kit>-context.md    # 任意。agent-context@1 の contentFile
└── README.md           # 日本語。他の kit に合わせる
```

ディレクトリ名と記述子のファイル名は一致させる（CI と `.claude/hooks/validate-kit-spec.sh` はこの規約で kit を見つける）。mixin は `.dockerfile` が無くてもよい（宣言だけの kit になる）。

```yaml
# syntax=docker/sandbox-kit:3
# Docker Sandboxes kit: <一行説明>. Usage and design notes: see README.md.
schemaVersion: "3"
kind: mixin
version: "1.0.0"
displayName: <Display Name>
description: <一文>
sourceUrl: https://github.com/nakahararuu/sbx-kits/tree/main/<kit>
requires: ["claude"]            # hook や context が claude CLI を前提にするときだけ

capabilities:
  - type: com.docker.sandbox/network-policy@1
    config:
      install:
        allow: [...]            # install hook が触るホスト
      runtime:
        allow: [...]            # エージェントと startup hook が触るホスト
  - type: com.docker.sandbox/lifecycle@1
    config:
      install:
        - command: |
            set -e
            ...
          user: "1000"          # root なら "0"
          env: [HTTP_PROXY, HTTPS_PROXY, NO_PROXY]
          description: ...
      startup:
        - command: [bash, -c, "..."]   # 起動のたびに走るので冪等にする
          user: "1000"
          background: true             # startup 専用
          description: ...
  - type: com.docker.sandbox/agent-context@1
    config:
      contentFile: ./<kit>-context.md
```

`requires: ["claude"]` は、`claude plugin install` などを使う kit では必須。依存順で workload の後に hook が走るようになり、workload の install hook が `~/.claude/settings.json` を書き換えても結果が消えない。

## 検証方法

`sbx kit validate` は v3 のソース kit を扱えない。kit frontend でビルドして検証する:

```bash
docker buildx build <kit> -f <kit>/<kit>.yaml --output type=cacheonly
```

kit ディレクトリ内のファイルを Edit/Write すると PostToolUse hook が自動でこれを実行し、失敗時は agent にフィードバックされる。CI（`.github/workflows/build-and-publish-kits.yml`）も pull request では同じビルドを全 kit に対して実行し（`DRY_RUN=1 scripts/publish-kit.sh <kit>`）、main への push で `ghcr.io/nakahararuu/sbx-kits/<kit>` に publish する。

ビルドで分かるのは記述子の書式（strict decode）と recipe が動くことだけ。ネットワーク許可・hook の挙動・overlay の所有者は検証されない。動作確認はホストで v3 workload と一緒に新規サンドボックスを作って行う（`sbx kit add` は既存の v3 サンドボックスに mixin を追加できないので作り直す）:

```bash
sbx run docker.io/docker/sbx-kit-claude:<tag> --kit ./<kit> .
# push 済みなら
sbx run docker.io/docker/sbx-kit-claude:<tag> --kit "git+https://github.com/nakahararuu/sbx-kits.git#ref=<branch>&dir=<kit>" .
# main にマージ済みなら（CI が publish したイメージ）
sbx run docker.io/docker/sbx-kit-claude:<tag> --kit ghcr.io/nakahararuu/sbx-kits/<kit>:latest .
```

ローカルパスと Git 参照では `sbx` がホストで kit をビルドするので、OCI exporter に対応した BuildKit が要る（Docker Desktop 既定の docker driver は `OCI exporter is not supported for the docker driver` で失敗する）。利用者向けの参照（README、`dot_sbxenv.yaml`）は公開イメージにする。

## 仕上げ

- kit の `README.md` を書く/更新する（何を入れるか、フェーズ付きの通信先の表、使い方）
- ルートの `README.md` の kit 一覧に行を追加する
- 「小・中規模の機能開発」構成に入れる kit なら、nakahararuu/dotfiles の `dot_sbxenv.yaml`（`~/.sbxenv.yaml`）にも `ghcr.io/nakahararuu/sbx-kits/<kit>:latest` で追加する（新しい kit は初回 publish 後に GitHub の package 設定で public にする）

## 落とし穴: v3 の書き方

### 1. strict decode — 知らないフィールドが1つでもあると失敗する

トップレベルのフィールドは仕様（SPEC-v3 §4）にあるものだけ。`name:` は無い（kit の識別子は参照 URL/イメージ名）。ネットワーク・hook・agent への指示・credential などはすべて `capabilities:` 配下の capability として書く。キーは lowerCamelCase（`sourceUrl`、`apiKey`）。

### 2. hook の環境変数は deny-by-default

`lifecycle@1` の hook には `PATH` / `HOME` などの最低限しか渡らない。hook 本体や子プロセスが読む変数はすべてその hook の `env: [...]` に列挙する。特に **curl / npm / pip / uv / apt / `claude plugin install` などネットワークに出るコマンドはプロキシ変数が必要**なので `env: [HTTP_PROXY, HTTPS_PROXY, NO_PROXY]` を付ける。ワークスペースのパスは `env: [WORKSPACE_DIR]`（`files` の中なら `${{ kit.env.WORKSPACE_DIR }}`）。sbx は startup hook の環境変数を絞らないが、仕様上は startup も deny-by-default なので同じように宣言する（例: `docker` を呼ぶなら `env: [DOCKER_HOST]`）。

### 3. `background: true` は startup hook 専用

install hook に `background` を書くと strict decode で落ちる。

### 4. `files/` は自動ではコピーされない

`files/` はただのビルドコンテキストで、recipe が `COPY` しない限りサンドボックスには何も置かれない。ワークスペースに置くファイルは `lifecycle@1` の `files` に `path: "${{ kit.env.WORKSPACE_DIR }}/..."` で書く（参考: `sample-ruff-lint`。`kit.env` は sbx v0.48.0 以降）。イメージに置くファイルは次の 5・6 を参照。

### 5. install hook は「焼き込めないか」を先に考える

v3 の mixin はイメージ（overlay）を持てる。ダウンロードして置くだけのバイナリは `.dockerfile` に移すと、サンドボックス作成時のネットワーク許可も要らなくなる（ビルド時の通信は network policy の対象外）。hook に残すべきなのは次のもの:
- `apt-get`（mixin は apt パッケージを overlay で運べない）
- `claude plugin install` のように、ベースが書くファイルへマージするもの
- 作成時にしか分からない値を使うもの

Docker デーモンが必要な処理は install hook では動かない（install 中は socket がマウントされていない）ので、startup hook に置く（参考: `docker-amd64`、`langfuse-claude`）。

### 6. overlay はホームを避け、置くなら所有者に注意する

recipe は build ステージで `/out` 以下に組み立て、`FROM scratch` + `COPY --from=build /out /` で overlay にする（RECIPES.md の "A mixin overlay"）。置き場所は `/usr/local` か `/opt` を優先し、`/home/agent` はできるだけ避ける（composed base ではボリュームがマウントされていることがある）。

ホームに置く場合、overlay のディレクトリエントリはベースのものを上書きするので、`/home` は root、`/home/agent` は uid 1000 の所有にしないといけない。どちらを間違えてもビルドは通るが、エージェントが `$HOME` を失う（SPEC-v3 §10 違反）。

```dockerfile
# NG: COPY files/home/ /home/agent/            → /home/agent が root 所有
# NG: COPY --chown=1000:1000 x /home/agent/x  → 親の /home まで 1000 所有
# OK: chown をちょうど /home/agent から始める
RUN mkdir -p /out/home/agent \
 && cp -a /src/files/home/. /out/home/agent/ \
 && chown -R 1000:1000 /out/home/agent
```

### 7. v3 サンドボックスでは全 kit が v3

組み込みの `claude` エージェント名とは組み合わせられない。`docker.io/docker/sbx-kit-claude` などの v3 workload と組み合わせる。docker/sbx-kits-contrib の kit は `#ref=v3&dir=<kit>` で v3 ブランチを参照する。

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

`apt-get update` は設定済みの全ソースを更新するので、ベースイメージのディストリビューションに合わせたミラーを install フェーズに入れる（参考: `chrome-devtools-host`）。`sbx-kit-claude` は 2.1.273 から DHI（Docker Hardened Images、Debian trixie）ベースになり、`deb.debian.org` と `dhi.io` を使う。それより前の Ubuntu ベースは `archive.ubuntu.com` / `security.ubuntu.com`（amd64）と `ports.ubuntu.com`（arm64）を使う。どちらでも `download.docker.com`（*-docker テンプレートが追加済み）が要る。ベースは workload のタグ更新で予告なく変わるので、両方を残しておく。

### 5. 動作確認の方法

network policy はサンドボックス内のプロキシが強制するものなので、hook のコマンドをサンドボックスの外でそのまま実行しても検証にはなりません。かならず kit を実際にサンドボックスへ適用して確認してください。許可が足りないドメインへの通信は HTTP 403 で拒否されます。拒否された通信はホスト側の `sbx policy log` で確認する（install hook の失敗も含めて出る）。サンドボックス内の `/var/log/sbx-kit-startup.log` に出るのは startup hook の出力だけ。出てきたホスト名を該当フェーズに追記してサンドボックスを作り直してください。

参考実装: `datadog-claude/datadog-claude.yaml`、`claude-documentation/claude-documentation.yaml`、`langfuse-claude/langfuse-claude.yaml`。

## 落とし穴: credentials（トークン注入）

APIキーやトークンをコンテナ内に注入する kit は `com.docker.sandbox/credential@1` を (service, phase) ごとに1つ書きます。

### 1. kit は「何が必要か」だけを宣言する。「どこにあるか」は書かない

```yaml
- type: com.docker.sandbox/credential@1
  optional: true          # 既定は必須。任意にするなら明示する
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

実トークンをどのホスト環境変数・ファイルから読むかは kit に書けません。「ホストの環境変数 `FOO_TOKEN` から取る」という要件は README で `sbx secret set <service> -t "$FOO_TOKEN"` を案内する形に落とし込む（サービスのシークレットは既定でグローバル。`sbxenv.yaml` の `secrets` / `bindings` で解決することもできる）。

### 2. `inject[].domain` は同じフェーズの allow に完全一致で入れる

`*.example.com` を allow していても、`api.example.com` への inject には仕様上その完全一致のホストが必要。ワイルドカードの横に完全一致のホストを書き足す。**この不整合は今の kit frontend のビルドでは検出されない**（hook も CI も通る）ので、自分で確認すること。

### 3. コンテナ内のトークン環境変数は実値ではない

`apiKey.proxyManaged: true` を設定すると、宣言したフェーズの間、コンテナ内の該当環境変数にはリテラル文字列 `proxy-managed` が入ります（`optional: true` で値が未登録なら entry ごと skip され、変数も設定されない）。実トークンはサンドボックス外のプロキシが、宣言した `inject[].domain` 宛のリクエストを流す瞬間に差し替える。トークンを埋め込む設定ファイル（`.npmrc` など）は `${GITHUB_TOKEN}` のようなプレースホルダを書いておき、ツール自身に実行時展開させる。

### 4. `lifecycle@1` の `files` で展開されるのは `${{ kit.* }}` だけ

`${GITHUB_TOKEN}` のようなシェル変数は展開されずにそのまま書かれる（ツール側で展開させたいならそれで良い）。hook の中で値を使う場合は `env:` に列挙する。
