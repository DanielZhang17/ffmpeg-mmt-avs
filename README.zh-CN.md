# FFmpeg MMT + AVS 编解码支持

[English](README.md) | [日本語](README.ja.md) | 简体中文

这是一个可复现的精简 FFmpeg 构建，用于将 MPEG Media Transport（MMT/MMTS）
录制文件提取为 MPEG-TS，并包含 AVS/AVS+、AVS2 和 AVS3 解码支持。

## 支持的功能

- 通过 `mmttlv` 解复用器读取 MMT/TLV
- AVS1-P2 基准档次和 AVS1-P16 广电档次（AVS+）解码
- 通过已打补丁的 `libdavs2` 解码 10-bit AVS2
- 通过 `libuavs3d` 解码 10-bit AVS3
- HEVC 与 AAC/AAC-LATM 解析和码流复制
- MPEG-TS 输入与输出

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

GitHub Actions 会在 push 和 pull request 时验证全部 6 个目标。推送以
`ffmpeg-git-` 开头并包含固定 FFmpeg 版本的标签后，工作流会构建相同矩阵，
并把压缩包附加到 GitHub Release。

```sh
git tag ffmpeg-git-2025-02-05-4b1cd60a47
git push origin ffmpeg-git-2025-02-05-4b1cd60a47
```

## 源码来源

- FFmpeg MMT：`SuperFashi/FFmpeg`，`tlvmmt` 修订版 `4b1cd60`
- AVS+ 移植：`nilaoda/mpv-iina-avs`，修订版 `2c69b7317c31`
- davs2 10-bit：`xatabhk/davs2-10bit`，修订版 `21d64c8f8e36`
- uavs3d：`uavs3/uavs3d`，修订版 `0e20d2c`

所有应用到固定上游版本的补丁均保存在 `patches/`。

## 许可证

由于启用了 `libdavs2`，生成的 FFmpeg 构建采用 GPL version 2 or later。详见
`LICENSE`。各上游依赖的许可证声明保存在 `licenses/`，并包含于每个发布包中。
