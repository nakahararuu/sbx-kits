# sbxenv

[`sbx env`](https://docs.docker.com/ai/sandboxes/configuration/environment-files/) のユーザーデフォルト（`~/.sbxenv.yaml`）。[wiki](https://github.com/nakahararuu/sbx-kits/wiki) の「小・中規模の機能開発」構成を定義しているので、任意のプロジェクトディレクトリで引数なしの `sbx env create`（作成のみ）/ `sbx env run`（作成してアタッチ）を実行するだけで同じサンドボックスが作れます。

## 構成

| 種類 | 内容 |
| --- | --- |
| agent | `sbx-kit-claude`（v3 の Claude Code workload `docker.io/docker/sbx-kit-claude`） |
| workspace | カレントディレクトリ（`${{ env.projectDir }}`）を clone モードでマウント（wiki の `--clone` 相当） |
| docker/sbx-kits-contrib（`v3` ブランチ） | `claude-sbx-statusline`, `git-ssh-sign`, `mise`, `neovim` |
| nakahararuu/sbx-kits（`main`） | `chrome-devtools-host`, `claude-documentation`, `claude-plugins-small-medium`, `docker-amd64`, `langfuse-claude`, `mise-runtimes`, `nakahararuu-claude-plugins` |

docker/sbx-kits-contrib の main ブランチは v2 kit のままで、v3 サンドボックスでは使えません（v3 サンドボックスでは全 kit が v3 である必要があります）。そのため `#ref=v3` で v3 ブランチを参照しています。

## 前提（ホストで一度だけ）

1. `sbx` v0.45 以降（v3 kit の対応バージョン）
2. Git kit の取得元を許可する（デフォルトは Docker Hub のみ。設定値は allowlist 全体を置き換えます）

   ```bash
   sbx settings set kit.allowedSources '["docker.io/","github.com/docker/","github.com/nakahararuu/"]'
   ```

3. `git-ssh-sign` 用に SSH agent forwarding を有効にしておく（`sbx settings get ssh.agentForwardingEnabled` が `true`）

## 配置

`~/.sbxenv.yaml` から、このファイルへシンボリックリンクを張ります。

```bash
ln -s ~/ghq/github.com/nakahararuu/sbx-kits/sbxenv/.sbxenv.yaml ~/.sbxenv.yaml
```

chezmoi で管理する場合は、dotfiles リポジトリに `symlink_dot_sbxenv.yaml.tmpl` を置き、中身をリンク先のパスにします。

```
{{ .chezmoi.homeDir }}/ghq/github.com/nakahararuu/sbx-kits/sbxenv/.sbxenv.yaml
```

## 使い方

```bash
cd ~/path/to/project
sbx env plan      # 何が作られるかを確認
sbx env create    # 作成（アタッチしない）
sbx env run       # 作成済みならアタッチ、無ければ作成してアタッチ
sbx env rm        # 削除
```

- サンドボックス名は `<agent>-<ディレクトリ名>` になります（ユーザーデフォルトでは `name` を指定できないため）。変えたいときは `--name` を付けます。
- プロジェクト側に `sbxenv.yaml` があれば、このユーザーデフォルトとマージされます（スカラー値はプロジェクト側が優先、リストは連結）。
- `sbx env create <path>` のようにパスを渡すと `~/.sbxenv.yaml` は読まれません。
- Claude Code を更新するときは `docker.io/docker/sbx-kit-claude` のタグを上げます。
