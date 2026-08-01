# mise-env

[docker/sbx-kits-contrib の `mise` kit](https://github.com/docker/sbx-kits-contrib/tree/main/mise) を拡張する mixin kit。以下の 2 つを行う。

1. mise で **Java / Go / Python / Node** を install するのに必要な domain を allow する
2. mise の per-directory ローカル上書きファイル `mise.local.toml`（`.mise.local.toml` も含む）を、どのディレクトリにあっても
   - git 管理対象から除外する（グローバル gitignore）
   - Claude Code の Read ツールで開けないようにする（`permissions.deny`）

この kit 単体では mise 自体はインストールしません。必ず本家 `mise` kit と併用してください。

```bash
sbx run claude --kit mise --kit "git+https://github.com/nakahararuu/sbx-kits.git#dir=mise-env"
```

## なぜ mise.local.toml を特別扱いするか

mise は `mise.toml` の上に重ねる、コミットしないためのローカル上書きファイル `mise.local.toml`（ドット始まりの `.mise.local.toml` も同義）をサポートしています。典型的な用途は `[env]` での環境変数定義で、`mise activate` がそのディレクトリに入るたびにシェルへ export します。つまり API キーやトークンなどの secrets を置く場所として使われがちです。

これは、このサンドボックス基盤が掲げる「サンドボックス内に credentials を保持しない」という思想と正面から衝突します。この kit はその衝突を解消するものではなく、あくまで **事故防止の速度制限** を 2 つ足すだけです。

1. `~/.config/git/ignore`（`core.excludesFile`）にファイル名を追加 — どのリポジトリ・どの階層でも `git add` の事故を防ぐ。特定プロジェクトの `.gitignore` は一切書き換えない。
2. `~/.claude/settings.json` の `permissions.deny` に `Read(//**/mise.local.toml)` / `Read(//**/.mise.local.toml)` を追加 — Claude Code の Read ツール、および Claude Code が Bash 経由でも認識する `cat`/`head`/`tail`/`sed` からの参照を拒否する（[公式ドキュメント](https://code.claude.com/docs/en/permissions.md)で確認済み）。`//` で始まる filesystem root 起点のパターンにしているのは、user-level settings.json に書く bare パターン（`Read(**/mise.local.toml)` 相当）は「今開いているプロジェクト配下」にしか届かず、サンドボックス内の別プロジェクトディレクトリまでは効かないため。

**どちらも本当の意味での secrets 境界にはなりません。** (2) は Claude Code 自身のツールと、それが認識する Bash コマンドしか塞がないため、`python3 -c "open('mise.local.toml').read()"` のような任意のサブプロセスによるファイルオープンまでは防げません。また `mise activate` で一度シェルに export されてしまえば、それ以降このエージェントが実行するあらゆるコマンド（`env`、エラー時のスタックトレースなど）から値は見えます。全プロセスに対する OS レベルの強制が必要なら `sandbox.filesystem.denyRead` の併用を検討してください。本当に secrets を守りたい場合は `mise.local.toml` に平文で置くのではなく、kit-spec の `credentials:` ブロック（proxy 側で管理され、コンテナ内に平文で書かれない）経由の注入を検討してください。

## ネットワーク

mise のコア plugin 実装（`jdx/mise` の `src/plugins/core/{node,go,python,java}.rs`）を直接確認して洗い出した、install 時・実行時の実通信先。

| 用途 | ドメイン | 備考 |
|------|----------|------|
| Node バージョン一覧（一次ソース） | `mise-versions.jdx.dev` | Node 以外の core plugin（go/java/python は対象外）でも汎用的に使われるキャッシュ層 |
| Node tarball / バージョン一覧のフォールバック | `nodejs.org` | `nodejs.org/dist/...` |
| Node musl(Alpine) 向け tarball | `unofficial-builds.nodejs.org` | 通常の Ubuntu(glibc) サンドボックスでは使われない想定。念のため許可 |
| Go tarball（デフォルト mirror） | `dl.google.com` | `go.download_mirror` のデフォルト値。リダイレクトなしで直接 200 を確認済み |
| Go バージョン一覧 | `github.com` | `git ls-remote --tags https://github.com/golang/go` を直接実行（mise-versions キャッシュは意図的に不使用） |
| Java バージョン・ダウンロード先メタデータ | `mise-java.jdx.dev` | `/jvm/<release_type>/<os>/<arch>.json` |
| Java 本体（デフォルト vendor = `openjdk`） | `download.java.net` | `java.shorthand_vendor` のデフォルトはこの vendor（実際のJSONレスポンスで確認済み） |
| Python 本体（precompiled、Linux x86_64/arm64のデフォルト経路） | `github.com`, `api.github.com`, `objects.githubusercontent.com` | astral-sh/python-build-standalone の GitHub Releases。releases API 一覧は `api.github.com`、`github.com/.../releases/download/...` は `objects.githubusercontent.com` へ 302 することを実際に確認済み |
| Java 本体（`temurin` 等 GitHub Releases 系 vendor） | 同上 | vendor 一覧の実データで `github.com`/`objects.githubusercontent.com` 配下と確認 |

上記の JSON で確認できた Java vendor のうち、GitHub 系でも `download.java.net` でもない **vendor 固有 CDN** は意図的に allowlist に入れていません。それらの vendor を pin する場合は追加してください。

| vendor | ドメイン |
|--------|----------|
| `zulu` | `cdn.azul.com` |
| `liberica` / `liberica-nik` | `download.bell-sw.com` |
| `jetbrains` | `cache-redirector.jetbrains.com` |
| `microsoft` | `aka.ms` |
| `oracle` / `oracle-graalvm` | `download.oracle.com` |
| `redhat` | `developers.redhat.com` |

## 使い方

```bash
sbx run claude --kit mise --kit "git+https://github.com/nakahararuu/sbx-kits.git#dir=mise-env"
```

kit 適用後:

```bash
mise use -g node@lts golang@latest python@latest java@openjdk-21
```

いずれの言語も、network policy に阻まれずに install できれば成功。

## 動作確認済み環境

- 本 README・spec.yaml の domain 一覧は、`jdx/mise` のソースコード（tag: 該当バージョン時点の `main`）の読み込みと、このモノレポの kit-dev サンドボックス上での実通信確認（`curl`、network policy を一時的に緩めた上でのリダイレクト先確認）に基づく。実際の `mise install` を通した end-to-end 検証は未実施のため、allowlist に漏れがあれば `sbx policy log` で block されたドメインを確認し追記してください。
