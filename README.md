# FFmpeg MMT + AVS codecs

English | [日本語](README.ja.md) | [简体中文](README.zh-CN.md)

Reproducible, minimal FFmpeg builds for extracting MPEG Media Transport
(MMT/MMTS) captures to MPEG-TS. The build includes AVS/AVS+, AVS2, and AVS3
decoding support.

## Included support

- MMT/TLV input through the `mmttlv` demuxer
- AVS1-P2 JiZhun and AVS1-P16 Guangdian (AVS+) decoding
- AVS2 10-bit decoding through the patched `libdavs2`
- AVS3 10-bit decoding through `libuavs3d`
- HEVC and AAC/AAC-LATM parsing and stream copy
- MPEG-TS input and output

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
amd64 Linux host using a pinned llvm-mingw toolchain. Build dependencies are
`git`, `cmake`, `make`, `pkg-config`, and standard C/C++ build tools. `curl`
and `xz` are also needed for Windows targets.

Output is written to `dist/`. Set `BUILD_ROOT` to keep intermediate source and
object files outside the repository.

## Automated releases

GitHub Actions verifies all six targets on pushes and pull requests. Pushing a
tag beginning with `ffmpeg-git-` and the pinned FFmpeg version builds the same
matrix and attaches the archives to a GitHub Release:

```sh
git tag ffmpeg-git-2025-02-05-4b1cd60a47
git push origin ffmpeg-git-2025-02-05-4b1cd60a47
```

The workflow can also be run manually from the Actions tab.

## Source provenance

- FFmpeg MMT source: `SuperFashi/FFmpeg`, `tlvmmt` revision `4b1cd60`
- AVS+ port: `nilaoda/mpv-iina-avs`, revision `2c69b7317c31`
- davs2 10-bit source: `xatabhk/davs2-10bit`, revision `21d64c8f8e36`
- uavs3d source: `uavs3/uavs3d`, revision `0e20d2c`

The patches applied to those pinned sources are kept in `patches/`.

## License

The resulting FFmpeg build is licensed under GPL version 2 or later because
`libdavs2` is enabled. See `LICENSE`. Upstream license notices are included in
`licenses/` and in every release archive.
