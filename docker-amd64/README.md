# docker-amd64

arm64 サンドボックス上で `--platform linux/amd64` の Docker コンテナを QEMU エミュレーションで実行できるようにする kit。

## インストール内容

- **`tonistiigi/binfmt` イメージの pull**（`install`）— `docker buildx` が内部で emulator セットアップに使っているのと同じイメージ。起動時にネットワークが未確立でも困らないよう事前 pull しておくだけで、登録自体はしない
- 毎起動時（`startup`）に以下を実行
  - `binfmt_misc` ファイルシステムのマウント（`/proc/sys/fs/binfmt_misc`。このサンドボックスではデフォルト未マウント）
  - `docker run --privileged tonistiigi/binfmt --install amd64` で `qemu-x86_64` を `binfmt_misc` に登録

マウントと登録はカーネル/ランタイムの状態であり、サンドボックス再起動で失われるため、`install`（一度きり）ではなく `startup`（毎起動・冪等）コマンドとして実装しています。

`qemu-x86_64` バイナリは apt パッケージとしてホストにインストールする必要はありません。`tonistiigi/binfmt` イメージが静的リンクされた qemu バイナリを自前で持っており、`binfmt_misc` の `F` フラグ（登録時にバイナリの中身をカーネルにキャッシュする）で登録するため、ホスト上にファイルを置く必要がないからです。apt パッケージを手動管理しない分、`tonistiigi/binfmt`（buildx が使っているのと同じ実装）の更新に自然に追随できます。

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

`docker run --privileged tonistiigi/binfmt --install ...` を `binfmt_misc` が未マウントの状態でいきなり単体実行すると、全アーキテクチャ分 "OK" と出るのに実際には何も残らない。`--pid=host` を付けない限り、コンテナは自分専用の使い捨てマウント名前空間内に独自の `binfmt_misc` インスタンスを作って register してしまい、コンテナ終了と同時にその登録が消えるため。本 kit は必ず先にホスト側で `binfmt_misc` をマウントしてから `tonistiigi/binfmt` を呼ぶことで、この問題を回避している。

## 動作確認済み環境

- アーキテクチャ: aarch64 (arm64)
- Docker Engine: 29.6.1
- OS: Ubuntu 24.x 系（`ports.ubuntu.com` ミラー）
