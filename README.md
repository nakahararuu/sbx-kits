# sbx-kits

[Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) 用の kit（mixin）を集めたモノレポです。各ディレクトリが 1 つの kit に対応し、kit-spec v3 の記述子 `<kit>/<kit>.yaml`（先頭行 `# syntax=docker/sandbox-kit:3`）で capability（ネットワークポリシー、lifecycle hook、agent-context など）を定義しています。

kit の仕様については [kit-spec v3](https://github.com/docker/sandbox-kit-spec/blob/main/docs/spec/SPEC-v3.md)、[`docs.docker.com` の Customize ドキュメント](https://docs.docker.com/ai/sandboxes/customize/) および `.claude/rules/kit-spec.md` を参照してください。

## Kit 一覧

| kit | 概要 |
| --- | --- |
| [`chrome-devtools-host`](./chrome-devtools-host) | ホストマシン上で動く Chrome を `chrome-devtools-mcp` 経由で操作できるようにする |
| [`claude-documentation`](./claude-documentation) | ClaudeがMiro、Cosenseを用いたドキュメンテーションを支援できるようにする |
| [`claude-plugins-small-medium`](./claude-plugins-small-medium) | 公式マーケットプレイスから小〜中規模開発向け plugin（context7, feature-dev, code-review, pr-review-toolkit, commit-commands, security-guidance, serena）一式をインストールする |
| [`datadog-claude`](./datadog-claude) | Datadogを使ったトラブルシューティング用ツール一式 |
| [`docker-amd64`](./docker-amd64) | arm64サンドボックスで `--platform linux/amd64` のDockerコンテナをQEMUエミュレーションで実行できるようにする |
| [`langfuse-claude`](./langfuse-claude) | サンドボックス内に Langfuse を docker compose でセルフホストし、公式 langfuse-observability plugin で Claude Code のテレメトリを可視化する |
| [`mise-runtimes`](./mise-runtimes) | `mise` kit を拡張し、Java/Go/Python/Node の install に必要な domain を許可する |
| [`nakahararuu-claude-plugins`](./nakahararuu-claude-plugins) | `nakahararuu/claude-plugins` marketplace を追加し、公開されている全プラグインをインストールする |
| [`sample-network-policy`](./sample-network-policy) | ネットワークポリシー（allow/deny）のみを設定するサンプル |
| [`sample-ruff-lint`](./sample-ruff-lint) | チーム共通設定付きで Ruff（Python linter）を導入するサンプル |

各 kit の詳細（前提条件やトラブルシューティングなど）は、それぞれのディレクトリの `README.md` および `<kit>-context.md`（agent-context）を参照してください。

## 使い方

v3 kit は v3 workload とだけ組み合わせられます（組み込みの `claude` エージェント名は v2 kit 用なので、v3 kit とは併用できません）。Claude Code を使う場合は `docker.io/docker/sbx-kit-claude` workload を指定します。`sbx` v0.48 以降が必要です（v3 kit 自体は v0.45 から使えますが、`sample-ruff-lint` が使う `kit.env` 参照は v0.48.0 からの対応です）。


### 公開イメージ

各 kit は CI（`.github/workflows/build-and-publish-kits.yml`）が main への push ごとにビルドし、OCI イメージとして GitHub Container Registry に publish しています（`linux/amd64` と `linux/arm64`）。

| タグ | 意味 |
| --- | --- |
| `ghcr.io/nakahararuu/sbx-kits/<kit>:latest` | main の最新。通常はこれを使う |
| `ghcr.io/nakahararuu/sbx-kits/<kit>:<version>` | 記述子の `version:`。publish のたびに付け替わる |
| `ghcr.io/nakahararuu/sbx-kits/<kit>:sha-<12桁>` | その commit からのビルド。付け替わらないので固定したいときに使う |

`git+https://github.com/nakahararuu/sbx-kits.git#dir=<kit>` のような Git 参照も書けますが、その場合 `sbx` がホストで kit をビルドします。v3 kit のビルドには OCI exporter に対応した BuildKit が必要で、Docker Desktop 既定の docker driver では `OCI exporter is not supported for the docker driver` で失敗します。普段は公開イメージを使ってください。

### 事前準備: kit の取得元を許可する

リモート kit の取得元はデフォルトで Docker Hub のみ許可されています。このリポジトリの kit（ghcr.io）を使うには、ホストで一度だけ次を実行します（設定値は allowlist 全体を置き換えます）。docker/sbx-kits-contrib の kit は `docker.io/sbx/<kit>` で公開されているので `docker.io/` で足ります。

```bash
sbx settings set kit.allowedSources '["docker.io/","ghcr.io/nakahararuu/"]'
```

### 新規サンドボックスを kit 付きで起動する

```bash
sbx run docker.io/docker/sbx-kit-claude:2.1.311 \
  --kit ghcr.io/nakahararuu/sbx-kits/<kit-name>:latest .
```

複数の kit を同時に指定することもできます。docker/sbx-kits-contrib の v3 kit は `docker.io/sbx/<kit>` を使います。

```bash
sbx run docker.io/docker/sbx-kit-claude:2.1.311 \
  --kit docker.io/sbx/mise:latest \
  --kit ghcr.io/nakahararuu/sbx-kits/mise-runtimes:latest \
  --kit ghcr.io/nakahararuu/sbx-kits/chrome-devtools-host:latest .
```

`sbx kit add` は既存の v3 サンドボックスに mixin を追加できないため、kit を足したいときはサンドボックスを作り直してください。

### kit を編集した場合は検証する

`sbx kit validate` は v3 のソース kit を扱えないので、kit frontend でビルドして検証します。CI も pull request では同じビルドを（push せずに）全 kit に対して実行しています。

```bash
docker buildx build <kit-name> -f <kit-name>/<kit-name>.yaml --output type=cacheonly
# CI と同じスクリプト（複数プラットフォームでビルドし、push はしない）
DRY_RUN=1 scripts/publish-kit.sh <kit-name>
```

マージ前のブランチの kit をサンドボックスで試すときは、OCI exporter に対応した BuildKit があるホストで Git 参照を使います（`kit.allowedSources` に `"github.com/nakahararuu/"` も追加してください）。

```bash
sbx run docker.io/docker/sbx-kit-claude:2.1.311 \
  --kit "git+https://github.com/nakahararuu/sbx-kits.git#ref=<branch>&dir=<kit-name>" .
```
