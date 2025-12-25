#!/bin/bash

# Redis HNP 编译脚本
# 使用 OpenHarmony 工具链编译 Redis 并打包为 HNP

set -e

# 设置 OpenHarmony SDK 路径
OHOS_SDK_PATH="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony"

# 检查 SDK 是否存在
if [ ! -d "$OHOS_SDK_PATH" ]; then
    echo "错误: OpenHarmony SDK 未找到，请检查路径: $OHOS_SDK_PATH"
    exit 1
fi

# 设置工具链路径
OHOS_CLANG="$OHOS_SDK_PATH/native/llvm/bin/aarch64-unknown-linux-ohos-clang"
OHOS_CLANGXX="$OHOS_SDK_PATH/native/llvm/bin/aarch64-unknown-linux-ohos-clang++"
OHOS_AR="$OHOS_SDK_PATH/native/llvm/bin/llvm-ar"
OHOS_RANLIB="$OHOS_SDK_PATH/native/llvm/bin/llvm-ranlib"
OHOS_SYSROOT="$OHOS_SDK_PATH/native/sysroot"
HNPCLI="$OHOS_SDK_PATH/toolchains/hnpcli"

# 检查工具是否存在
if [ ! -f "$OHOS_CLANG" ]; then
    echo "错误: OpenHarmony 编译器未找到: $OHOS_CLANG"
    exit 1
fi

echo "========================================="
echo "Redis HNP 编译脚本"
echo "========================================="
echo "SDK 路径: $OHOS_SDK_PATH"
echo "编译器: $OHOS_CLANG"
echo "========================================="

# 进入 Redis 源码目录
REDIS_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$REDIS_DIR"

# 清理之前的构建
echo "清理之前的构建..."
make distclean 2>/dev/null || true
rm -rf hnp_build hnp_package *.hnp

# 创建构建目录
mkdir -p hnp_build hnp_package

# 设置编译环境变量
export CC="$OHOS_CLANG"
export CXX="$OHOS_CLANGXX"
export AR="$OHOS_AR"
export RANLIB="$OHOS_RANLIB"
export STRIP="$OHOS_SDK_PATH/native/llvm/bin/llvm-strip"

# 设置编译选项
export CFLAGS="--target=aarch64-unknown-linux-ohos --sysroot=$OHOS_SYSROOT -D__linux__ -D__MUSL__ -fPIC"
export CXXFLAGS="--target=aarch64-unknown-linux-ohos --sysroot=$OHOS_SYSROOT -fPIC"
export LDFLAGS="--target=aarch64-unknown-linux-ohos --sysroot=$OHOS_SYSROOT -lpthread -ldl -lrt"

# 禁用一些可能不兼容的功能
export BUILD_TLS=no
export BUILD_WITH_MODULES=no
export DISABLE_WERRORS=yes
export MALLOC=libc

echo "开始编译依赖库..."
cd deps

# 编译 hiredis
echo "编译 hiredis..."
cd hiredis
make clean 2>/dev/null || true
make static CC="$OHOS_CLANG" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" AR="$OHOS_AR" RANLIB="$OHOS_RANLIB" 2>&1 | tail -20
cd ..

# 编译 linenoise
echo "编译 linenoise..."
cd linenoise
make clean 2>/dev/null || true
make CC="$OHOS_CLANG" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" 2>&1 | tail -10
cd ..

# 编译 lua
echo "编译 lua..."
cd lua/src
make clean 2>/dev/null || true
make all CC="$OHOS_CLANG" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" AR="$OHOS_AR" RANLIB="$OHOS_RANLIB" 2>&1 | tail -30
cd ../..

# 编译其他依赖
echo "编译其他依赖..."
for lib in hdr_histogram fpconv fast_float xxhash; do
    echo "编译 $lib..."
    cd $lib
    make clean 2>/dev/null || true
    make CC="$OHOS_CLANG" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" AR="$OHOS_AR" RANLIB="$OHOS_RANLIB" 2>&1 | tail -10 || true
    cd ..
done

cd "$REDIS_DIR"

echo "开始编译 Redis..."
make clean 2>/dev/null || true

# 编译 Redis
# 强制设置 uname_S 为 Linux 以便 Makefile 添加正确的库
make CC="$OHOS_CLANG" \
     CXX="$OHOS_CLANGXX" \
     AR="$OHOS_AR" \
     RANLIB="$OHOS_RANLIB" \
     CFLAGS="$CFLAGS" \
     CXXFLAGS="$CXXFLAGS" \
     LDFLAGS="$LDFLAGS" \
     REDIS_LDFLAGS="-lpthread -ldl -lrt" \
     BUILD_TLS=no \
     BUILD_WITH_MODULES=no \
     DISABLE_WERRORS=yes \
     MALLOC=libc \
     -j4 2>&1 | tee hnp_build/build.log | tail -100

# 检查编译结果
if [ ! -f "src/redis-server" ]; then
    echo "错误: 编译失败，redis-server 未生成"
    echo "请查看 hnp_build/build.log 了解详情"
    exit 1
fi

# 验证可执行文件
echo "验证编译结果..."
file src/redis-server

# 检查是否是 ARM64 Linux ELF 格式
if ! file src/redis-server | grep -q "ARM aarch64.*ELF"; then
    echo "警告: 生成的文件可能不是正确的格式"
    file src/redis-server
fi

# 准备打包目录
echo "准备打包目录..."
cp src/redis-server hnp_package/
cp src/redis-cli hnp_package/ 2>/dev/null || true
cp redis.conf hnp_package/ 2>/dev/null || true

# 打包为 HNP
echo "打包为 HNP..."
$HNPCLI pack \
    -i hnp_package \
    -n redis \
    -v 8.4.0

if [ $? -ne 0 ]; then
    echo "错误: 打包失败"
    exit 1
fi

echo "========================================="
echo "编译完成！"
echo "HNP 文件: redis.hnp"
echo "========================================="
ls -lh redis.hnp
