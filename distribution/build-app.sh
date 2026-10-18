#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
arch="${1:-arm64}"
app="$PWD/distribution/build-$arch/YouTube MP4 Downloader.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/Licenses"
xcrun swiftc -O -target "$arch-apple-macosx13.0" -framework AppKit main.swift progress.swift completion.swift -o "$app/Contents/MacOS/YouTubeMP4Downloader"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleExecutable</key><string>YouTubeMP4Downloader</string><key>CFBundleIdentifier</key><string>local.ren.youtube-mp4-downloader</string><key>CFBundleName</key><string>YouTube MP4 Downloader</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleShortVersionString</key><string>1.2.1</string><key>CFBundleIconFile</key><string>AppIcon</string><key>LSMinimumSystemVersion</key><string>13.0</string><key>NSHighResolutionCapable</key><true/></dict></plist>
PLIST
/usr/libexec/PlistBuddy -c 'Set :LSMinimumSystemVersion 13.0' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 1.2.1' "$app/Contents/Info.plist"
cp distribution/deps/yt-dlp_macos "$app/Contents/Resources/yt-dlp"
cp assets/completion-marimba.wav "$app/Contents/Resources/"
if [[ ! -f distribution/work/AppIcon.icns ]]; then
 xcrun swift make-icon.swift distribution/work
 iconutil -c icns distribution/work/AppIcon.iconset -o distribution/work/AppIcon.icns
fi
cp distribution/work/AppIcon.icns "$app/Contents/Resources/"
cp "distribution/work/ffmpeg-$arch/ffmpeg" "$app/Contents/Resources/ffmpeg"
nodearch=arm64; [[ "$arch" == x86_64 ]] && nodearch=x64
cp "distribution/work/node-v22.23.3-darwin-$nodearch/bin/node" "$app/Contents/Resources/node"
cp YT-DLP*LICENSE*.txt "$app/Contents/Resources/Licenses/"
cp distribution/work/ffmpeg-8.1.3/COPYING.LGPLv2.1 "$app/Contents/Resources/Licenses/FFmpeg-LGPL-2.1.txt"
cp "distribution/work/node-v22.23.3-darwin-$nodearch/LICENSE" "$app/Contents/Resources/Licenses/Node-LICENSE.txt"
cp distribution/THIRD-PARTY.md "$app/Contents/Resources/Licenses/"
chmod +x "$app/Contents/Resources/"{ffmpeg,node,yt-dlp}
for binary in ffmpeg node yt-dlp; do codesign --force --sign - "$app/Contents/Resources/$binary"; done
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict "$app"
