# mise-runtimes

[docker/sbx-kits-contrib の `mise` kit](https://github.com/docker/sbx-kits-contrib/tree/main/mise) を拡張する mixin kit。mise で **Java / Go / Python / Node** を install するのに必要な domain を allow する。

この kit 単体では mise 自体はインストールしません。必ず本家 `mise` kit と併用してください。

```bash
sbx run claude --kit mise --kit "git+https://github.com/nakahararuu/sbx-kits.git#dir=mise-runtimes"
```

## ネットワーク

mise のコア plugin 実装(`jdx/mise` の `src/plugins/core/{node,go,python,java}.rs`)を直接確認して洗い出した、install 時・実行時の実通信先。

| 用途 | ドメイン | 備考 |
|------|----------|------|
| Node バージョン一覧(一次ソース) | `mise-versions.jdx.dev` | Node 以外の core plugin(go/java/python は対象外)でも汎用的に使われるキャッシュ層 |
| Node tarball / バージョン一覧のフォールバック | `nodejs.org` | `nodejs.org/dist/...` |
| Node musl(Alpine) 向け tarball | `unofficial-builds.nodejs.org` | 通常の Ubuntu(glibc) サンドボックスでは使われない想定。念のため許可 |
| Go tarball(デフォルト mirror) | `dl.google.com` | `go.download_mirror` のデフォルト値。リダイレクトなしで直接 200 を確認済み |
| Go バージョン一覧 | `github.com` | `git ls-remote --tags https://github.com/golang/go` を直接実行(mise-versions キャッシュは意図的に不使用) |
| Java バージョン・ダウンロード先メタデータ | `mise-java.jdx.dev` | `/jvm/<release_type>/<os>/<arch>.json` |
| Java 本体(デフォルト vendor = `openjdk`) | `download.java.net` | `java.shorthand_vendor` のデフォルトはこの vendor(実際のJSONレスポンスで確認済み) |
| Python 本体(precompiled、Linux x86_64/arm64のデフォルト経路) | `github.com`, `api.github.com`, `objects.githubusercontent.com` | astral-sh/python-build-standalone の GitHub Releases。releases API 一覧は `api.github.com`、`github.com/.../releases/download/...` は `objects.githubusercontent.com` へ 302 することを実際に確認済み |
| Java 本体(`temurin` 等 GitHub Releases 系 vendor) | 同上 | vendor 一覧の実データで `github.com`/`objects.githubusercontent.com` 配下と確認 |

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
sbx run claude --kit mise --kit "git+https://github.com/nakahararuu/sbx-kits.git#dir=mise-runtimes"
```

kit 適用後:

```bash
mise use -g node@lts golang@latest python@latest java@openjdk-21
```

いずれの言語も、network policy に阻まれずに install できれば成功。
