# v1.2.1 Apple Silicon配布検証（2026-10-19）

- arm64アプリとffmpegをmacOS13ターゲットにクロスビルド。Node22.23.3公式arm64、yt-dlp2026.08.19公式Universalを同梱。
- アプリ・FFmpeg・NodeのMach-Oアーキテクチャと最小OSを確認。外部dylibはAppleのシステムライブラリ/Frameworkのみ。Homebrew参照なし。
- 公式ソースFFmpeg8.1.3のPGP署名を公式鍵指紋で検証。Node/yt-dlpの配布SHA256を照合。
- 同じソース/構成のIntel検証版で画質3段階、URL検証、進捗計算、完了音条件、WAVデコードのローカルテスト成功。
- PATH=/usr/bin:/binのIntel検証版で公開動画の5秒区間を実保存。同梱ffmpegとNodeを優先して使用。640×360/H.264、AAC音声、5.033333秒をffprobe確認、保存1/失敗0。
- 最終arm64アプリのアドホック署名の整合とZIP内容を確認。AppleのDeveloper ID署名/公証は未実施。
- Apple Silicon実機での起動・ダウンロードは未検証。Intelで実行した結果をApple Silicon実機検証とみなしていません。

実担当モデル: GPT-6.1 Sol。既存のIntelインストール版/ZIPは変更なし。
