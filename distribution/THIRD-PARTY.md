# 同梱ソフトウェアと対応ソース

- yt-dlp 2026.08.19: https://github.com/yt-dlp/yt-dlp/releases/tag/2026.08.19 。独立実行ファイル。Unlicenseおよび同梱依存のライセンスはYT-DLP-LICENSE.txtとYT-DLP-THIRD-PARTY-LICENSES.txtを参照。改変なし（配布時のローカル署名のみ）。
- Node.js22.23.3: https://nodejs.org/dist/v22.23.3/ 。公式macOSバイナリ。MITおよび同梱第三者ライセンスをNode-LICENSE.txtに全文収録。バイナリ変更なし（ローカル署名のみ）。ソース https://nodejs.org/dist/v22.23.3/node-v22.23.3.tar.xz 。
- FFmpeg8.1.3: https://ffmpeg.org/releases/ffmpeg-8.1.3.tar.xz 。LGPL2.1-or-later、外部codecライブラリ・GPL・nonfree機能を使わない独立CLIビルド。アプリとはProcessで通信。FFmpegのコードは改変なし。正確なソースアーカイブ、署名、ビルドスクリプトはこのアプリと同じGitHubReleaseに提供。FFmpeg-LGPL-2.1.txtを参照。

FFmpegの再ビルド: sourceアーカイブをdistribution/workに展開し、Xcode Command Line ToolsがあるMacでdistribution/build-ffmpeg.sh arm64を実行。配布対象はmacOS13以降。Apple Silicon実行環境でのテストは未実施。コード署名はアドホック署名で、Appleによる公証はしていません。
