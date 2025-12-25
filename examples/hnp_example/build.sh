#!/bin/bash

# HarmonyOS Native Package (HNP) 编译脚本
# 使用方法: ./build.sh

set -e

# 设置 OpenHarmony SDK 路径
OHOS_SDK_PATH="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony"

# 检查 SDK 是否存在
if [ ! -d "$OHOS_SDK_PATH" ]; then
    echo "错误: OpenHarmony SDK 未找到，请检查路径: $OHOS_SDK_PATH"
    exit 1
fi

# 设置编译器路径
CLANG="$OHOS_SDK_PATH/native/llvm/bin/aarch64-unknown-linux-ohos-clang"
SYSROOT="$OHOS_SDK_PATH/native/sysroot"
HNPCLI="$OHOS_SDK_PATH/toolchains/hnpcli"

# 项目配置
PROJECT_NAME="my_hnp_project"
VERSION="1.0.0"
ARCH="aarch64"

echo "========================================="
echo "HarmonyOS Native Package 编译脚本"
echo "========================================="
echo "项目名称: $PROJECT_NAME"
echo "版本: $VERSION"
echo "架构: $ARCH"
echo "========================================="

# 清理之前的构建
echo "清理之前的构建..."
rm -rf build package *.hnp
mkdir -p build package

# 编译源代码
echo "编译源代码..."
$CLANG \
    --target=aarch64-unknown-linux-ohos \
    --sysroot=$SYSROOT \
    -o build/my_hnp_app \
    main.c

if [ $? -ne 0 ]; then
    echo "错误: 编译失败"
    exit 1
fi

echo "编译成功: build/my_hnp_app"

# 验证可执行文件
echo "验证可执行文件..."
file build/my_hnp_app

# 准备打包目录
echo "准备打包目录..."
cp build/my_hnp_app package/

# 打包为 HNP
echo "打包为 HNP..."
$HNPCLI pack \
    -i package \
    -n $PROJECT_NAME \
    -v $VERSION

if [ $? -ne 0 ]; then
    echo "错误: 打包失败"
    exit 1
fi

echo "========================================="
echo "编译完成！"
echo "HNP 文件: ${PROJECT_NAME}.hnp"
echo "========================================="
ls -lh ${PROJECT_NAME}.hnp

