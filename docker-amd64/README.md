# docker-amd64

arm64 サンドボックス上で `--platform linux/amd64` の Docker コンテナを QEMU エミュレーションで実行できるようにする kit。

## インストール内容

- **qemu-user-binfmt**（apt パッケージ）— `/usr/bin/qemu-x86_64` を提供
- 毎起動時（`startup`）に以下を実行
  - `binfmt_misc` ファイルシステムのマウント（`/proc/sys/fs/binfmt_misc`。このサンドボックスではデフォルト未マウント）
  - `qemu-x86_64` を ELF x86_64 バイナリのインタプリタとして `binfmt_misc` に登録

マウントと登録はカーネル/ランタイムの状態であり、サンドボックス再起動で失われるため、`install`（一度きり）ではなく `startup`（毎起動・冪等）コマンドとして実装しています。

## 使い方

```bash
sbx run claude --kit /path/to/docker-amd64/
```

kit 適用後:

```bash
docker run --rm --platform linux/amd64 alpine uname -m
# → x86_64 と表示されれば成功
```

## 既知の落とし穴

`docker run --privileged tonistiigi/binfmt --install all`（buildx が内部で使うイメージ）は、成功したように見えるログを出すが、このサンドボックスでは実際には emulation を有効化しない。`binfmt_misc` に直接 register する本 kit の方式のみが動作する。

## 動作確認済み環境

- アーキテクチャ: aarch64 (arm64)
- Docker Engine: 29.6.1
- OS: Ubuntu 24.x 系（`ports.ubuntu.com` ミラー）
