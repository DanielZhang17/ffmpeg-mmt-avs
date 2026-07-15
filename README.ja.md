# Full FFmpeg 8.1.2 + MMT + AVS コーデック

[English](README.md) | 日本語 | [简体中文](README.zh-CN.md)

公式 FFmpeg 8.1.2 をベースとする再現可能な汎用ビルドです。FFmpeg 内蔵の
コーデック、フォーマット、プロトコル、フィルターをすべて維持しながら、
MMT/MMTS と AVS/AVS+/AVS2/AVS3 に対応します。

## 対応機能

- HTTP/HTTPS、RTP/RTSP、RTMP/RTMPS、TCP、UDP、TLS/DTLS、FTP、Icecast
- 静的リンクした OpenSSL 3.5.7 LTS による TLS 1.3
- MPEG-TS、MP4、Matroska/WebM、MOV、FLV、HLS、DASH、AVI、MXF、WAV
- FFmpeg 内蔵の全デコーダー、エンコーダー、パーサー、ビットストリーム
  フィルター、音声・映像フィルター
- `mmttlv` デマルチプレクサーによる MMT/TLV 入力
- AVS1-P2 JiZhun および AVS1-P16 Guangdian（AVS+）デコード
- パッチ適用済み `libdavs2` による AVS2 10-bit デコード
- `libuavs3d` による AVS3 10-bit デコード
- H.264、HEVC、VVC、AV1、VP8/VP9、MPEG-2/4、AAC、AC-3/E-AC-3、MP3、
  FLAC、Opus、Vorbis などの主要内蔵デコーダー
- x264/x265 による H.264/HEVC エンコード
- libaom、dav1d、SVT-AV1 による AV1 エンコード・デコード
- libvpx による VP8/VP9 エンコード・デコード
- MP3、Opus、Vorbis、Speex、Theora、WebP、JPEG 2000、JPEG XL
- FreeType、Fontconfig、FriBidi、HarfBuzz による ASS/SSA 字幕描画
- SRT、SFTP、libopenmpt、SoX リサンプリング、Snappy、XML、BZip2、LZMA、Zlib

`--enable-nonfree` コンポーネントは使用していません。ハードウェアアクセラレーション
は upstream FFmpeg と同様にプラットフォーム依存です。

Windows、macOS、Linux の amd64 および arm64 向けリリースを提供します。

## MMTS から MPEG-TS への変換

```sh
ffmpeg -f mmttlv -i input.mmts \
  -map 0:v:0 -map 0:a -c copy -f mpegts output.ts
```

再エンコードせず、最初の映像ストリームとすべての音声ストリームをコピーします。
この MPEG-TS 出力経路では入力形式の TTML 字幕を格納できないため、字幕は除外します。

## ローカルビルド

```sh
./scripts/build.sh macos arm64
./scripts/build.sh linux amd64
./scripts/build.sh windows arm64
```

macOS と Linux はネイティブビルドです。Windows は amd64 Linux 上で、固定した
llvm-mingw ツールチェーンを使ってクロスコンパイルします。成果物は `dist/` に
出力されます。

## 自動リリース

GitHub Actions は push と pull request ごとに全 6 ターゲットを検証します。
`ffmpeg-*-mmt` に一致するタグを push すると、同じマトリックスをビルドし、
各アーカイブを GitHub Release に添付します。

```sh
git tag ffmpeg-8.1.2-full-mmt
git push origin ffmpeg-8.1.2-full-mmt
```

## ソース

- FFmpeg: 公式 8.1.2、リビジョン `38b88335f99e`
- MMT/TLV: `SuperFashi/FFmpeg`、リビジョン `4b1cd60`
- AVS+ 移植: `nilaoda/mpv-iina-avs`、リビジョン `2c69b7317c31`
- davs2 10-bit: `xatabhk/davs2-10bit`、リビジョン `21d64c8f8e36`
- uavs3d: `uavs3/uavs3d`、リビジョン `0e20d2c`
- OpenSSL: 3.5.7 LTS、リビジョン `6ca677c395a4`
- 依存関係レシピ: vcpkg リビジョン `8e8dfb4ba483`

適用するパッチは `patches/` に収録されています。

## ライセンス

生成される FFmpeg ビルドは GPL version 3 or later です。収録する GPL Codec
ライブラリのため GPL モードを使用し、version-3 モードも明示的に有効化しています。
各リリースには静的リンクされた全依存関係のライセンス通知が
`licenses/vcpkg/` に収録されています。詳細は `LICENSE` を参照してください。
