# FFmpeg MMT + AVS コーデック

[English](README.md) | 日本語 | [简体中文](README.zh-CN.md)

MMT/MMTS（MPEG Media Transport）キャプチャーを MPEG-TS に抽出するための、
再現可能な最小構成 FFmpeg ビルドです。AVS/AVS+、AVS2、AVS3 のデコードにも
対応しています。

## 対応機能

- `mmttlv` デマルチプレクサーによる MMT/TLV 入力
- AVS1-P2 JiZhun および AVS1-P16 Guangdian（AVS+）デコード
- パッチ適用済み `libdavs2` による AVS2 10-bit デコード
- `libuavs3d` による AVS3 10-bit デコード
- HEVC および AAC/AAC-LATM の解析とストリームコピー
- MPEG-TS 入出力

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
固定した FFmpeg バージョンを含む `ffmpeg-git-` で始まるタグを push すると、
同じマトリックスをビルドし、各アーカイブを GitHub Release に添付します。

```sh
git tag ffmpeg-git-2025-02-05-4b1cd60a47
git push origin ffmpeg-git-2025-02-05-4b1cd60a47
```

## ソース

- FFmpeg MMT: `SuperFashi/FFmpeg`、`tlvmmt` リビジョン `4b1cd60`
- AVS+ 移植: `nilaoda/mpv-iina-avs`、リビジョン `2c69b7317c31`
- davs2 10-bit: `xatabhk/davs2-10bit`、リビジョン `21d64c8f8e36`
- uavs3d: `uavs3/uavs3d`、リビジョン `0e20d2c`

適用するパッチは `patches/` に収録されています。

## ライセンス

`libdavs2` を有効にしているため、生成される FFmpeg ビルドは GPL version 2
or later です。詳細は `LICENSE` を参照してください。各依存ソフトウェアの
ライセンス表記は `licenses/` とリリースアーカイブに収録されています。
