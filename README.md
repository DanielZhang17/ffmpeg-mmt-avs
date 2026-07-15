# Full FFmpeg 8.1.2 + MMT + AVS codecs

English | [日本語](README.ja.md) | [简体中文](README.zh-CN.md)

Reproducible, general-purpose builds based on the official FFmpeg 8.1.2
release. They retain FFmpeg's complete built-in codec, format, protocol, and
filter sets, add broad statically linked portable libraries, and add MMT/MMTS
plus AVS/AVS+/AVS2/AVS3 support.

## Included support

- HTTP, HTTPS, RTP, RTSP, RTMP/RTMPS, TCP, UDP, TLS/DTLS, FTP, Icecast, and
  FFmpeg's other built-in network protocols
- TLS 1.3 through statically linked OpenSSL 3.5.7 LTS
- Mainstream formats including MPEG-TS, MP4, Matroska/WebM, MOV, FLV, HLS,
  DASH, AVI, MXF, WAV, and image formats
- FFmpeg's full built-in decoder, encoder, parser, bitstream-filter, and
  audio/video filter sets
- MMT/TLV input through the `mmttlv` demuxer
- AVS1-P2 JiZhun and AVS1-P16 Guangdian (AVS+) decoding
- AVS2 10-bit decoding through the patched `libdavs2`
- AVS3 10-bit decoding through `libuavs3d`
- Mainstream built-in decoders including H.264, HEVC, VVC, AV1, VP8/VP9,
  MPEG-2/4, AAC, AC-3/E-AC-3, MP3, FLAC, Opus, and Vorbis
- H.264/HEVC encoding through x264/x265
- AV1 encoding and decoding through libaom, dav1d, and SVT-AV1
- VP8/VP9 encoding and decoding through libvpx
- MP3, Opus, Vorbis, Speex, Theora, WebP, JPEG 2000, and JPEG XL external codecs
- ASS/SSA rendering with FreeType, Fontconfig, FriBidi, and HarfBuzz
- SRT, SFTP, SoX resampling, Snappy, XML, BZip2, LZMA, and Zlib

No `--enable-nonfree` components are used. Hardware acceleration remains
platform-dependent, as in upstream FFmpeg.

Release archives are built for:

| Platform | amd64 | arm64 |
| --- | --- | --- |
| Windows | yes | yes |
| macOS | yes | yes |
| Linux | yes | yes |

## Convert MMTS to MPEG-TS

```sh
ffmpeg -f mmttlv -i input.mmts \
  -map 0:v:0 -map 0:a -c copy -f mpegts output.ts
```

The command copies the first video stream and every audio stream without
re-encoding. TTML subtitle streams are omitted because this MPEG-TS output
path cannot carry their input representation directly.

## Build locally

The build script accepts a target platform and architecture:

```sh
./scripts/build.sh macos arm64
./scripts/build.sh linux amd64
./scripts/build.sh windows arm64
```

macOS and Linux builds are native. Windows builds are cross-compiled on an
amd64 Linux host using a pinned llvm-mingw toolchain. Codec dependencies are
built from pinned source through vcpkg. The host needs standard C/C++ tools,
Git, CMake, Make, pkg-config, Autoconf, Automake, Libtool, Meson, Ninja,
NASM/Yasm, Perl, Python, curl, patch, and archive tools.

Output is written to `dist/`. Set `BUILD_ROOT` to keep intermediate source and
object files outside the repository.

## Automated releases

GitHub Actions verifies all six targets on pushes and pull requests. Pushing a
tag matching `ffmpeg-*-mmt` builds the same matrix and attaches the archives
to a GitHub Release:

```sh
git tag ffmpeg-8.1.2-full-mmt
git push origin ffmpeg-8.1.2-full-mmt
```

The workflow can also be run manually from the Actions tab.

## Source provenance

- FFmpeg: official 8.1.2 release, revision `38b88335f99e`
- MMT/TLV support: `SuperFashi/FFmpeg`, revision `4b1cd60`
- AVS+ port: `nilaoda/mpv-iina-avs`, revision `2c69b7317c31`
- davs2 10-bit source: `xatabhk/davs2-10bit`, revision `21d64c8f8e36`
- uavs3d source: `uavs3/uavs3d`, revision `0e20d2c`
- OpenSSL: 3.5.7 LTS, revision `6ca677c395a4`
- Portable dependency recipes: vcpkg revision `8e8dfb4ba483`

The patches applied to those pinned sources are kept in `patches/`.

## License

The resulting FFmpeg build is licensed under GPL version 3 or later. GPL mode
is required by the included GPL codec libraries, and FFmpeg's version-3 mode
is deliberately enabled. See `LICENSE`. Every archive includes the upstream
notice for each statically linked dependency under `licenses/vcpkg/`.
