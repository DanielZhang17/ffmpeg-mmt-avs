#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TARGET_OS=${1:-}
TARGET_ARCH=${2:-}

FFMPEG_REPOSITORY=https://github.com/SuperFashi/FFmpeg.git
FFMPEG_REVISION=4b1cd60
DAVS2_REPOSITORY=https://github.com/xatabhk/davs2-10bit.git
DAVS2_REVISION=21d64c8f8e36
UAVS3D_REPOSITORY=https://github.com/uavs3/uavs3d.git
UAVS3D_REVISION=0e20d2c
LLVM_MINGW_VERSION=20260616

usage() {
    echo "usage: $0 <macos|linux|windows> <amd64|arm64>" >&2
    exit 2
}

case "$TARGET_OS" in
    macos|linux|windows) ;;
    *) usage ;;
esac

case "$TARGET_ARCH" in
    amd64|arm64) ;;
    *) usage ;;
esac

host_os=$(uname -s)
host_arch=$(uname -m)
case "$host_arch" in
    x86_64) host_arch=amd64 ;;
    arm64|aarch64) host_arch=arm64 ;;
esac

if [[ "$TARGET_OS" = macos && "$host_os" != Darwin ]]; then
    echo "macOS targets must be built on macOS" >&2
    exit 1
fi
if [[ "$TARGET_OS" = linux && "$host_os" != Linux ]]; then
    echo "Linux targets must be built on Linux" >&2
    exit 1
fi
if [[ "$TARGET_OS" != windows && "$TARGET_ARCH" != "$host_arch" ]]; then
    echo "$TARGET_OS/$TARGET_ARCH must be built on a matching native runner" >&2
    exit 1
fi
if [[ "$TARGET_OS" = windows && ( "$host_os" != Linux || "$host_arch" != amd64 ) ]]; then
    echo "Windows targets must be cross-compiled on Linux/amd64" >&2
    exit 1
fi

for tool in git cmake make pkg-config; do
    command -v "$tool" >/dev/null || { echo "missing build dependency: $tool" >&2; exit 1; }
done

BUILD_ROOT=${BUILD_ROOT:-"$ROOT_DIR/build/$TARGET_OS-$TARGET_ARCH"}
SOURCE_ROOT="$BUILD_ROOT/src"
DEPS_ROOT="$BUILD_ROOT/deps"
PREFIX="$BUILD_ROOT/prefix"
OUTPUT_ROOT="$BUILD_ROOT/output"
DIST_ROOT="$ROOT_DIR/dist"
JOBS=${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu)}

rm -rf "$BUILD_ROOT"
mkdir -p "$SOURCE_ROOT" "$DEPS_ROOT" "$PREFIX" "$OUTPUT_ROOT/bin" "$DIST_ROOT"

clone_revision() {
    local repository=$1
    local revision=$2
    local destination=$3
    git clone --filter=blob:none --no-checkout "$repository" "$destination"
    git -C "$destination" checkout --detach "$revision"
}

clone_revision "$FFMPEG_REPOSITORY" "$FFMPEG_REVISION" "$SOURCE_ROOT/ffmpeg"
clone_revision "$DAVS2_REPOSITORY" "$DAVS2_REVISION" "$SOURCE_ROOT/davs2"
clone_revision "$UAVS3D_REPOSITORY" "$UAVS3D_REVISION" "$SOURCE_ROOT/uavs3d"

git -C "$SOURCE_ROOT/ffmpeg" apply \
    "$ROOT_DIR/patches/0001-avformat-mmttlv-skip-unsupported-interleaved-packets.patch"
git -C "$SOURCE_ROOT/ffmpeg" apply \
    "$ROOT_DIR/patches/0001-avcodec-cavs-add-AVS-Guangdian-profile-decoding.patch"

davs2_patches=(0001 0010)
if [[ "$TARGET_ARCH" = arm64 ]]; then
    davs2_patches=(0001 0002 0003 0004 0005 0006 0007 0008 0009 0010)
fi
if [[ "$TARGET_OS" = macos && "$TARGET_ARCH" = amd64 ]]; then
    davs2_patches+=(0011)
fi
for patch_number in "${davs2_patches[@]}"; do
    patch_file=$(find "$ROOT_DIR/patches/davs2-10bit" -name "${patch_number}-*.patch" -print -quit)
    git -C "$SOURCE_ROOT/davs2" apply "$patch_file"
done

cc=cc
cxx=c++
ar=ar
ranlib=ranlib
strip=strip
target_triple=
cmake_platform_args=(-DCMAKE_POLICY_VERSION_MINIMUM=3.5)
ffmpeg_platform_args=()

if [[ "$TARGET_OS" = windows ]]; then
    for tool in curl tar; do
        command -v "$tool" >/dev/null || { echo "missing build dependency: $tool" >&2; exit 1; }
    done
    llvm_archive="llvm-mingw-${LLVM_MINGW_VERSION}-ucrt-ubuntu-22.04-x86_64.tar.xz"
    llvm_url="https://github.com/mstorsjo/llvm-mingw/releases/download/${LLVM_MINGW_VERSION}/${llvm_archive}"
    curl --fail --location --retry 3 "$llvm_url" --output "$DEPS_ROOT/$llvm_archive"
    tar -xf "$DEPS_ROOT/$llvm_archive" -C "$DEPS_ROOT"
    toolchain_root="$DEPS_ROOT/llvm-mingw-${LLVM_MINGW_VERSION}-ucrt-ubuntu-22.04-x86_64"
    if [[ "$TARGET_ARCH" = amd64 ]]; then
        target_triple=x86_64-w64-mingw32
        cmake_processor=x86_64
        ffmpeg_arch=x86_64
    else
        target_triple=aarch64-w64-mingw32
        # uavs3d's AArch64 assembly uses ELF directives that are not valid in
        # Windows COFF objects. Its portable C decoder still supports AVS3.
        cmake_processor=generic
        ffmpeg_arch=aarch64
    fi
    export PATH="$toolchain_root/bin:$PATH"
    cc="$target_triple-clang"
    cxx="$target_triple-clang++"
    ar="$target_triple-ar"
    ranlib="$target_triple-ranlib"
    strip="$target_triple-strip"
    cmake_platform_args+=(
        -DCMAKE_SYSTEM_NAME=Windows
        -DCMAKE_SYSTEM_PROCESSOR="$cmake_processor"
        -DCMAKE_CROSSCOMPILING_EMULATOR=/bin/false
    )
    ffmpeg_platform_args=(
        --enable-cross-compile
        --target-os=mingw32
        --arch="$ffmpeg_arch"
        --cross-prefix="$target_triple-"
    )
elif [[ "$TARGET_OS" = macos ]]; then
    cc=clang
    cxx=clang++
    ffmpeg_arch=$([[ "$TARGET_ARCH" = amd64 ]] && echo x86_64 || echo arm64)
    ffmpeg_platform_args=(--arch="$ffmpeg_arch")
else
    cc=gcc
    cxx=g++
    ffmpeg_arch=$([[ "$TARGET_ARCH" = amd64 ]] && echo x86_64 || echo aarch64)
    ffmpeg_platform_args=(--arch="$ffmpeg_arch")
fi

cc=$(command -v "$cc")
cxx=$(command -v "$cxx")
ar=$(command -v "$ar")
ranlib=$(command -v "$ranlib")
strip=$(command -v "$strip")

cmake -S "$SOURCE_ROOT/uavs3d" -B "$BUILD_ROOT/uavs3d-build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_C_COMPILER="$cc" \
    -DCMAKE_CXX_COMPILER="$cxx" \
    -DCMAKE_ASM_COMPILER="$cc" \
    -DCMAKE_AR="$ar" \
    -DCMAKE_RANLIB="$ranlib" \
    -DBUILD_SHARED_LIBS=OFF \
    -DCOMPILE_10BIT=ON \
    "${cmake_platform_args[@]}"
cmake --build "$BUILD_ROOT/uavs3d-build" --parallel "$JOBS"
cmake --install "$BUILD_ROOT/uavs3d-build"

pushd "$SOURCE_ROOT/davs2/build/linux" >/dev/null
davs2_configure=(--prefix="$PREFIX" --disable-cli --bit-depth=10)
if [[ "$TARGET_OS" = windows ]]; then
    davs2_configure+=(--host="$target_triple" --cross-prefix="$target_triple-")
    if [[ "$TARGET_ARCH" = arm64 ]]; then
        davs2_configure+=(--disable-asm)
    fi
elif [[ "$TARGET_OS" = macos && "$TARGET_ARCH" = arm64 ]]; then
    davs2_configure+=(--host=aarch64-apple-darwin)
elif [[ "$TARGET_OS" = macos ]]; then
    davs2_configure+=(--host=x86_64-apple-darwin)
elif [[ "$TARGET_ARCH" = arm64 ]]; then
    davs2_configure+=(--host=aarch64-linux-gnu)
else
    davs2_configure+=(--host=x86_64-linux-gnu)
fi
CC="$cc" AR="$ar" RANLIB="$ranlib" STRIP="$strip" ./configure "${davs2_configure[@]}"
make -j"$JOBS"
make install
popd >/dev/null

export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"
export PKG_CONFIG_PATH=

ffmpeg_configure=(
    --prefix="$OUTPUT_ROOT"
    --disable-doc
    --disable-debug
    --disable-autodetect
    --disable-everything
    --enable-gpl
    --enable-ffmpeg
    --enable-ffprobe
    --enable-demuxer=mmttlv,mpegts,cavsvideo,avs2,avs3
    --enable-muxer=mpegts,cavsvideo,avs2,avs3
    --enable-protocol=file
    --enable-parser=hevc,aac,aac_latm,cavsvideo,avs2,avs3
    --enable-decoder=hevc,aac,aac_latm,cavs,libdavs2,libuavs3d
    --enable-bsf=hevc_mp4toannexb,aac_adtstoasc
    --enable-libdavs2
    --enable-libuavs3d
    --pkg-config-flags=--static
    --cc="$cc"
    --cxx="$cxx"
    --ld="$cxx"
    --ar="$ar"
    --ranlib="$ranlib"
    --strip="$strip"
    --extra-cflags=-I$PREFIX/include
    --extra-ldflags=-L$PREFIX/lib
    "${ffmpeg_platform_args[@]}"
)

pushd "$SOURCE_ROOT/ffmpeg" >/dev/null
./configure "${ffmpeg_configure[@]}"
make -j"$JOBS"
make install
popd >/dev/null

cp "$ROOT_DIR/README.md" "$OUTPUT_ROOT/"
cp -R "$ROOT_DIR/licenses" "$OUTPUT_ROOT/"
cp -R "$ROOT_DIR/patches" "$OUTPUT_ROOT/"

archive_base="ffmpeg-mmt-${TARGET_OS}-${TARGET_ARCH}"
if [[ "$TARGET_OS" = windows ]]; then
    command -v zip >/dev/null || { echo "missing packaging dependency: zip" >&2; exit 1; }
    (cd "$OUTPUT_ROOT" && zip -9 -r "$DIST_ROOT/$archive_base.zip" .)
    archive="$DIST_ROOT/$archive_base.zip"
else
    tar -cJf "$DIST_ROOT/$archive_base.tar.xz" -C "$OUTPUT_ROOT" .
    archive="$DIST_ROOT/$archive_base.tar.xz"
fi

echo "created $archive"
