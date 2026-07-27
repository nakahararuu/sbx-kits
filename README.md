# sbx-kits

[Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) 用の kit（mixin）を集めたモノレポです。各ディレクトリが 1 つの kit に対応し、`spec.yaml` でネットワークポリシーやインストール/起動コマンドを定義しています。

kit の仕様（schemaVersion、caps.network、commands など）については [`docs.docker.com` の Kits ドキュメント](https://docs.docker.com/ai/sandboxes/customize/kits/) および `.claude/rules/kit-spec.md` を参照してください。

## Kit 一覧

| kit | 概要 |
| --- | --- |
| [`sbx-kit-dev`](./sbx-kit-dev) | このモノレポで kit を開発するためのツールをインストールするkit |
| [`chrome-devtools-host`](./chrome-devtools-host) | ホストマシン上で動く Chrome を `chrome-devtools-mcp` 経由で操作できるようにする |
| [`claude-documentation`](./claude-documentation) | ClaudeがMiro、Cosenseを用いたドキュメンテーションを支援できるようにする |
| [`datadog-claude`](./datadog-claude) | Datadogを使ったトラブルシューティング用ツール一式 |
| [`nakahararuu-claude-plugins`](./nakahararuu-claude-plugins) | `nakahararuu/claude-plugins` marketplace を追加し、公開されている全プラグインをインストールする |
| [`sample-network-policy`](./sample-network-policy) | ネットワークポリシー（allow/deny）のみを設定するサンプル |
| [`sample-ruff-lint`](./sample-ruff-lint) | チーム共通設定付きで Ruff（Python linter）を導入するサンプル |

各 kit の詳細（前提条件やトラブルシューティングなど）は、それぞれのディレクトリの `README.md` および `spec.yaml` の `agentContext` を参照してください。

## 使い方

### 新規サンドボックスを kit 付きで起動する

git リポジトリのディレクトリを直接指定できるので、クローンは不要です。

```bash
sbx run <agent> --kit "git+https://github.com/nakahararuu/sbx-kits.git#dir=<kit-name>"
```

例: `datadog-claude` kit を付けて Claude Code サンドボックスを起動する

```bash
sbx run claude --kit "git+https://github.com/nakahararuu/sbx-kits.git#dir=datadog-claude"
```

複数の kit を同時に指定することもできます。

```bash
sbx run claude \
  --kit "git+https://github.com/nakahararuu/sbx-kits.git#dir=sbx-kit-dev" \
  --kit "git+https://github.com/nakahararuu/sbx-kits.git#dir=chrome-devtools-host"
```

### 既存のサンドボックスに kit を追加する

```bash
sbx kit add <sandbox名> "git+https://github.com/nakahararuu/sbx-kits.git#dir=<kit-name>"
```

### kit を編集した場合は validate する

`spec.yaml` を変更したら、コミット前に `sbx-kit-dev` kit が提供する `sbx` CLI で検証してください。

```bash
sbx kit validate /path/to/sbx-kits/<kit-name>/
```

`sbx kit inspect` / `sbx kit pack` も利用できます。詳しくは `sbx-kit-dev/README.md` を参照してください。
