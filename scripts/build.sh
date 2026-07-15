#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TARGET_OS=${1:-}
TARGET_ARCH=${2:-}

FFMPEG_REPOSITORY=https://github.com/FFmpeg/FFmpeg.git
FFMPEG_REVISION=38b88335f99e76ed89ff3c93f877fdefce736c13
FFMPEG_VERSION=8.1.2
DAVS2_REPOSITORY=https://github.com/xatabhk/davs2-10bit.git
DAVS2_REVISION=21d64c8f8e36
UAVS3D_REPOSITORY=https://github.com/uavs3/uavs3d.git
UAVS3D_REVISION=0e20d2c
VCPKG_REPOSITORY=https://github.com/microsoft/vcpkg.git
VCPKG_REVISION=8e8dfb4ba483886936ded5ca201b500b8d8b0096
OPENSSL_VERSION=3.5.7
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
clone_revision "$VCPKG_REPOSITORY" "$VCPKG_REVISION" "$SOURCE_ROOT/vcpkg"

git -C "$SOURCE_ROOT/ffmpeg" apply \
    "$ROOT_DIR/patches/0001-avformat-add-MMTP-parser-and-MMT-TLV-demuxer.patch"
git -C "$SOURCE_ROOT/ffmpeg" apply \
    "$ROOT_DIR/patches/0001-avformat-mmttlv-skip-unsupported-interleaved-packets.patch"
git -C "$SOURCE_ROOT/ffmpeg" apply \
    "$ROOT_DIR/patches/0001-avcodec-cavs-add-AVS-Guangdian-profile-decoding.patch"

if [[ "$TARGET_OS" = windows && "$TARGET_ARCH" = arm64 ]]; then
    git -C "$SOURCE_ROOT/uavs3d" apply \
        "$ROOT_DIR/patches/uavs3d/0001-use-portable-c-functions-on-windows-arm64.patch"
fi

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
if [[ "$TARGET_OS" = windows && "$TARGET_ARCH" = arm64 ]]; then
    git -C "$SOURCE_ROOT/davs2" apply \
        "$ROOT_DIR/patches/davs2-10bit/0012-use-standard-setjmp-on-windows-arm64.patch"
fi

cc=cc
cxx=c++
ar=ar
ranlib=ranlib
strip=strip
target_triple=
cmake_platform_args=(-DCMAKE_POLICY_VERSION_MINIMUM=3.5)
ffmpeg_platform_args=()
extra_libs=
vcpkg_triplet=

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
    extra_libs="-lc++ -lws2_32 -lbcrypt"
    vcpkg_triplet=$([[ "$TARGET_ARCH" = amd64 ]] && echo x64-mingw-static || echo arm64-mingw-static)
elif [[ "$TARGET_OS" = macos ]]; then
    cc=clang
    cxx=clang++
    ffmpeg_arch=$([[ "$TARGET_ARCH" = amd64 ]] && echo x86_64 || echo arm64)
    ffmpeg_platform_args=(--arch="$ffmpeg_arch")
    extra_libs=-lc++
    vcpkg_triplet=$([[ "$TARGET_ARCH" = amd64 ]] && echo x64-osx || echo arm64-osx)
    export PATH="$(brew --prefix libtool)/libexec/gnubin:$PATH"
    macos_sdk=$(xcrun --sdk macosx --show-sdk-path)
    export CXXFLAGS="${CXXFLAGS:+$CXXFLAGS }-isystem $macos_sdk/usr/include/c++/v1"
else
    cc=gcc
    cxx=g++
    ffmpeg_arch=$([[ "$TARGET_ARCH" = amd64 ]] && echo x86_64 || echo aarch64)
    ffmpeg_platform_args=(--arch="$ffmpeg_arch")
    extra_libs=-lstdc++
    vcpkg_triplet=$([[ "$TARGET_ARCH" = amd64 ]] && echo x64-linux || echo arm64-linux)
fi

cc=$(command -v "$cc")
cxx=$(command -v "$cxx")
ar=$(command -v "$ar")
ranlib=$(command -v "$ranlib")
strip=$(command -v "$strip")

vcpkg_overlay="$BUILD_ROOT/vcpkg-overlay"
mkdir -p "$vcpkg_overlay"
cp -R "$SOURCE_ROOT/vcpkg/ports/openssl" "$vcpkg_overlay/"
patch --directory="$vcpkg_overlay" --strip=1 \
    --input="$ROOT_DIR/patches/vcpkg/0001-pin-openssl-3.5.7.patch"
"$SOURCE_ROOT/vcpkg/bootstrap-vcpkg.sh" -disableMetrics
"$SOURCE_ROOT/vcpkg/vcpkg" install \
    --triplet "$vcpkg_triplet" \
    --x-manifest-root="$ROOT_DIR" \
    --x-install-root="$BUILD_ROOT/vcpkg-installed" \
    --overlay-ports="$vcpkg_overlay" \
    --clean-after-build
VCPKG_PREFIX="$BUILD_ROOT/vcpkg-installed/$vcpkg_triplet"

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
davs2_configure=(--prefix="$PREFIX" --disable-cli --bit-depth=10 --enable-pic)
if [[ "$TARGET_OS" = windows ]]; then
    davs2_configure+=(--host="$target_triple" --cross-prefix="$target_triple-")
elif [[ "$TARGET_OS" = macos && "$TARGET_ARCH" = arm64 ]]; then
    davs2_configure+=(--host=aarch64-apple-darwin)
elif [[ "$TARGET_OS" = macos ]]; then
    davs2_configure+=(--host=x86_64-apple-darwin)
elif [[ "$TARGET_ARCH" = arm64 ]]; then
    davs2_configure+=(--host=aarch64-linux-gnu)
else
    davs2_configure+=(--host=x86_64-linux-gnu)
fi
if [[ "$TARGET_ARCH" = arm64 ]]; then
    # The davs2 fork does not contain the AArch64 assembly sources referenced
    # by its build files. Use its complete portable decoder implementation.
    davs2_configure+=(--disable-asm)
fi
CC="$cc" AR="$ar" RANLIB="$ranlib" STRIP="$strip" ./configure "${davs2_configure[@]}"
make -j"$JOBS"
make install
popd >/dev/null

export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig:$VCPKG_PREFIX/lib/pkgconfig:$VCPKG_PREFIX/share/pkgconfig"
export PKG_CONFIG_PATH=

openssl_version=$(pkg-config --modversion openssl)
if [[ "$openssl_version" != "$OPENSSL_VERSION" ]]; then
    echo "expected OpenSSL $OPENSSL_VERSION, found $openssl_version" >&2
    exit 1
fi

ffmpeg_configure=(
    --prefix="$OUTPUT_ROOT"
    --disable-doc
    --disable-debug
    --disable-autodetect
    --disable-shared
    --enable-static
    --enable-gpl
    --enable-version3
    --enable-ffmpeg
    --enable-ffprobe
    --enable-bzlib
    --enable-iconv
    --enable-libaom
    --enable-libass
    --enable-libdavs2
    --enable-libdav1d
    --enable-libfontconfig
    --enable-libfreetype
    --enable-libfribidi
    --enable-libharfbuzz
    --enable-libjxl
    --enable-libmp3lame
    --enable-libopenjpeg
    --enable-libopus
    --enable-libsnappy
    --enable-libsoxr
    --enable-libspeex
    --enable-libsrt
    --enable-libssh
    --enable-libsvtav1
    --enable-libtheora
    --enable-libuavs3d
    --enable-libvorbis
    --enable-libvpx
    --enable-libwebp
    --enable-libx264
    --enable-libx265
    --enable-libxml2
    --enable-lzma
    --enable-openssl
    --enable-zlib
    --pkg-config=pkg-config
    --pkg-config-flags=--static
    --cc="$cc"
    --cxx="$cxx"
    --ld="$cxx"
    --ar="$ar"
    --ranlib="$ranlib"
    --strip="$strip"
    --extra-cflags="-I$PREFIX/include -I$VCPKG_PREFIX/include"
    --extra-ldflags="-L$PREFIX/lib -L$VCPKG_PREFIX/lib"
    --extra-libs="$extra_libs"
    "${ffmpeg_platform_args[@]}"
)

pushd "$SOURCE_ROOT/ffmpeg" >/dev/null
if ! ./configure "${ffmpeg_configure[@]}"; then
    tail -n 200 ffbuild/config.log >&2
    exit 1
fi
for feature in \
    CONFIG_MMTTLV_DEMUXER \
    CONFIG_HTTP_PROTOCOL \
    CONFIG_HTTPS_PROTOCOL \
    CONFIG_RTP_PROTOCOL \
    CONFIG_RTSP_DEMUXER \
    CONFIG_RTSP_MUXER \
    CONFIG_RTMP_PROTOCOL \
    CONFIG_RTMPS_PROTOCOL \
    CONFIG_TCP_PROTOCOL \
    CONFIG_TLS_PROTOCOL \
    CONFIG_UDP_PROTOCOL \
    CONFIG_LIBSRT_PROTOCOL \
    CONFIG_LIBSSH_PROTOCOL \
    CONFIG_CAVS_DECODER \
    CONFIG_LIBAOM_AV1_DECODER \
    CONFIG_LIBAOM_AV1_ENCODER \
    CONFIG_LIBDAV1D_DECODER \
    CONFIG_LIBDAVS2_DECODER \
    CONFIG_LIBJXL_DECODER \
    CONFIG_LIBJXL_ENCODER \
    CONFIG_LIBMP3LAME_ENCODER \
    CONFIG_LIBOPENJPEG_ENCODER \
    CONFIG_LIBOPUS_DECODER \
    CONFIG_LIBOPUS_ENCODER \
    CONFIG_LIBSPEEX_DECODER \
    CONFIG_LIBSPEEX_ENCODER \
    CONFIG_LIBSVTAV1_ENCODER \
    CONFIG_LIBUAVS3D_DECODER \
    CONFIG_LIBVORBIS_DECODER \
    CONFIG_LIBVORBIS_ENCODER \
    CONFIG_LIBVPX_VP8_DECODER \
    CONFIG_LIBVPX_VP8_ENCODER \
    CONFIG_LIBVPX_VP9_DECODER \
    CONFIG_LIBVPX_VP9_ENCODER \
    CONFIG_LIBWEBP_ENCODER \
    CONFIG_LIBX264_ENCODER \
    CONFIG_LIBX265_ENCODER; do
    grep -qx "$feature=yes" ffbuild/config.mak || {
        echo "required FFmpeg feature is disabled: $feature" >&2
        exit 1
    }
done
make -j"$JOBS"
make install
popd >/dev/null

cp "$ROOT_DIR/README.md" "$ROOT_DIR/README.ja.md" "$ROOT_DIR/README.zh-CN.md" "$OUTPUT_ROOT/"
cp "$ROOT_DIR/LICENSE" "$OUTPUT_ROOT/"
cp -R "$ROOT_DIR/licenses" "$OUTPUT_ROOT/"
cp -R "$ROOT_DIR/patches" "$OUTPUT_ROOT/"
mkdir -p "$OUTPUT_ROOT/licenses/vcpkg"
for copyright_file in "$VCPKG_PREFIX"/share/*/copyright; do
    package_name=$(basename "$(dirname "$copyright_file")")
    cp "$copyright_file" "$OUTPUT_ROOT/licenses/vcpkg/$package_name.txt"
done

archive_base="ffmpeg-${FFMPEG_VERSION}-mmt-${TARGET_OS}-${TARGET_ARCH}"
if [[ "$TARGET_OS" = windows ]]; then
    command -v zip >/dev/null || { echo "missing packaging dependency: zip" >&2; exit 1; }
    (cd "$OUTPUT_ROOT" && zip -9 -r "$DIST_ROOT/$archive_base.zip" .)
    archive="$DIST_ROOT/$archive_base.zip"
else
    tar -cJf "$DIST_ROOT/$archive_base.tar.xz" -C "$OUTPUT_ROOT" .
    archive="$DIST_ROOT/$archive_base.tar.xz"
fi

echo "created $archive"
