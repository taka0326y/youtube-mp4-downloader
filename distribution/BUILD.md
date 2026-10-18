# ソースから再ビルド

Xcode Command Line Tools、Python3、curl、makeを利用します。有料API不要。macOS13以降。

```sh
./distribution/prepare-deps.sh
./distribution/build-ffmpeg.sh arm64
./distribution/build-app.sh arm64
```

生成先はdistribution/build-arm64/YouTube MP4 Downloader.app。ソースは原版v1.2.1。ffmpeg8.1.3の公式ソースを無改変で使います。prepare-deps.shに取得元とSHA256を固定。公開時はFFmpeg公式PGP署名を公開鍵指紋FCF986EA15E6E293A5644F10B4322F04D67658D8で照合済み。

Intel検証版はprepare-deps.sh --intel-test、build-ffmpeg.sh x86_64、build-app.sh x86_64で生成できます。通常のbuild.shはローカル開発用の別構成です。

各ツールを別プロセスとして起動し、アプリ内Resourcesのffmpeg/nodeを優先します。公開用パッケージはHomebrew依存なし。GitHub Releaseにアプリと同じFFmpegソースtar.xz、署名、ソース一式とチェックサムを添付します。
