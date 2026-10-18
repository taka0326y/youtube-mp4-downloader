#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p deps work
fetch() { [[ -f "deps/$2" ]] || curl -fL --retry 2 "$1" -o "deps/$2"; }
verify() { printf '%s  %s\n' "$1" "deps/$2" | shasum -a 256 -c -; }
fetch https://ffmpeg.org/releases/ffmpeg-8.1.3.tar.xz ffmpeg-8.1.3.tar.xz
verify 7138d28c96d9d3e3af4ee3d8cad72741f8ffb40da90c1112235dea3ecd3178a3 ffmpeg-8.1.3.tar.xz
fetch https://github.com/yt-dlp/yt-dlp/releases/download/2026.08.19/yt-dlp_macos yt-dlp_macos
verify 0f192b7ec147ab6288885d6351d9ab67367640029b4377576ef46dd79cf7b202 yt-dlp_macos
fetch https://nodejs.org/dist/v22.23.3/node-v22.23.3-darwin-arm64.tar.gz node-v22.23.3-darwin-arm64.tar.gz
verify 23b25245dcfb9af7262f8ff142e9e2e0af025368117329e7a7458a51e5922f53 node-v22.23.3-darwin-arm64.tar.gz
tar -xf deps/ffmpeg-8.1.3.tar.xz -C work
tar -xf deps/node-v22.23.3-darwin-arm64.tar.gz -C work
if [[ "${1:-}" == --intel-test ]]; then
 fetch https://nodejs.org/dist/v22.23.3/node-v22.23.3-darwin-x64.tar.gz node-v22.23.3-darwin-x64.tar.gz
 verify 8a677b0219178efd6eb0e475457c4afb452b521a92f6e67845a73bd85727f2a8 node-v22.23.3-darwin-x64.tar.gz
 tar -xf deps/node-v22.23.3-darwin-x64.tar.gz -C work
fi
