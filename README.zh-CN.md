# Full FFmpeg 8.1.2 + MMT + AVS 编解码支持

[English](README.md) | [日本語](README.ja.md) | 简体中文

这是基于官方 FFmpeg 8.1.2 的可复现通用构建。它保留 FFmpeg 全部内置编解码器、
格式、协议和滤镜，同时加入 MMT/MMTS 与 AVS/AVS+/AVS2/AVS3 支持。

## 支持的功能

- HTTP/HTTPS、RTP/RTSP、RTMP/RTMPS、TCP、UDP、TLS/DTLS、FTP、Icecast
- 通过静态链接的 Mbed TLS 3.6.6 提供 TLS
- MPEG-TS、MP4、Matroska/WebM、MOV、FLV、HLS、DASH、AVI、MXF、WAV
- FFmpeg 全部内置解码器、编码器、解析器、码流滤镜及音视频滤镜
- 通过 `mmttlv` 解复用器读取 MMT/TLV
- AVS1-P2 基准档次和 AVS1-P16 广电档次（AVS+）解码
- 通过已打补丁的 `libdavs2` 解码 10-bit AVS2
- 通过 `libuavs3d` 解码 10-bit AVS3
- H.264、HEVC、VVC、AV1、VP8/VP9、MPEG-2/4、AAC、AC-3/E-AC-3、MP3、
  FLAC、Opus、Vorbis 等主流内置解码器

本项目不启用 `--enable-nonfree` 组件。硬件加速能力与上游 FFmpeg 一样，取决于平台。

发布包覆盖 Windows、macOS、Linux 的 amd64 和 arm64，共 6 个目标。

## 将 MMTS 转换为 MPEG-TS

```sh
ffmpeg -f mmttlv -i input.mmts \
  -map 0:v:0 -map 0:a -c copy -f mpegts output.ts
```

该命令不重新编码，直接复制第一路视频和所有音频流。由于此 MPEG-TS 输出路径
无法直接承载输入格式中的 TTML 字幕，字幕流会被省略。

## 本地构建

```sh
./scripts/build.sh macos arm64
./scripts/build.sh linux amd64
./scripts/build.sh windows arm64
```

macOS 和 Linux 使用原生构建；Windows 在 amd64 Linux 主机上使用固定版本的
llvm-mingw 交叉编译。生成的压缩包位于 `dist/`。

## 自动发布

GitHub Actions 会在 push 和 pull request 时验证全部 6 个目标。推送符合
`ffmpeg-*-mmt` 的标签后，工作流会构建相同矩阵，并把压缩包附加到 GitHub Release。

```sh
git tag ffmpeg-8.1.2-mmt
git push origin ffmpeg-8.1.2-mmt
```

## 源码来源

- FFmpeg：官方 8.1.2，修订版 `38b88335f99e`
- MMT/TLV：`SuperFashi/FFmpeg`，修订版 `4b1cd60`
- AVS+ 移植：`nilaoda/mpv-iina-avs`，修订版 `2c69b7317c31`
- davs2 10-bit：`xatabhk/davs2-10bit`，修订版 `21d64c8f8e36`
- uavs3d：`uavs3/uavs3d`，修订版 `0e20d2c`
- Mbed TLS：3.6.6，修订版 `0bebf8b8c7f0`

所有应用到固定上游版本的补丁均保存在 `patches/`。

## 许可证

生成的 FFmpeg 构建采用 GPL version 3 or later。`libdavs2` 要求 GPL 模式，
Mbed TLS 则要求启用 FFmpeg 的 version-3 模式。详见 `LICENSE`。各上游依赖的
许可证声明保存在 `licenses/`，并包含于每个发布包中。
