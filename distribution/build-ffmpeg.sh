#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
arch="${1:-arm64}"
source_dir="$PWD/work/ffmpeg-8.1.3"
mkdir -p "work/ffmpeg-$arch"
cd "work/ffmpeg-$arch"
"$source_dir/configure" --arch="$arch" --target-os=darwin --enable-cross-compile --cc="clang -arch $arch -mmacosx-version-min=13.0" --disable-autodetect --disable-asm --disable-doc --disable-debug --disable-shared --enable-static --disable-ffplay --disable-ffprobe --disable-avdevice --disable-everything --enable-ffmpeg --enable-protocol=file,http,https,tcp,tls,crypto --enable-securetransport --enable-demuxer=mov,matroska,mpegts,hls,aac,mp3 --enable-muxer=mp4,mov,matroska,adts --enable-parser=aac,h264,hevc,opus,vp9,av1,mpegaudio --enable-bsf=aac_adtstoasc,h264_mp4toannexb,hevc_mp4toannexb,extract_extradata --enable-decoder=aac,mp3,opus,vorbis,flac,pcm_s16le --enable-encoder=aac --enable-filter=aresample,anull,aformat --enable-swresample > configure.log 2>&1
make -j 8 > build.log 2>&1
