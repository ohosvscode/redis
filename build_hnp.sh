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
APP_PACKING_TOOL="$OHOS_SDK_PATH/toolchains/lib/app_packing_tool.jar"
SOFT_NAME="redis"

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
rm -rf hnp_build $SOFT_NAME *.hnp

# 创建构建目录
mkdir -p hnp_build $SOFT_NAME

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

# 准备打包目录（按照 HNP 标准目录结构）
echo "准备打包目录..."
mkdir -p $SOFT_NAME/bin $SOFT_NAME/cfg
cp src/redis-server $SOFT_NAME/bin/
cp src/redis-cli $SOFT_NAME/bin/ 2>/dev/null || true
cp redis.conf $SOFT_NAME/cfg/ 2>/dev/null || true

# 创建 hnp.json 配置文件（按照 HNP 标准格式）
echo "创建 hnp.json 配置文件..."
cat > $SOFT_NAME/hnp.json << 'EOF'
{
    "type": "hnp-config",
    "name": "redis",
    "version": "8.4.0",
    "install": {
        "links": [
            {
                "source": "/bin/redis-server",
                "target": "redis-server"
            },
            {
                "source": "/bin/redis-cli",
                "target": "redis-cli"
            }
        ]
    }
}
EOF

# 打包为 HNP
echo "打包为 HNP..."
$HNPCLI pack -i $SOFT_NAME -v 8.4.0

if [ $? -ne 0 ]; then
    echo "错误: 打包失败"
    exit 1
fi

echo "========================================="
echo "编译完成！"
echo "HNP 文件: redis.hnp"
echo "========================================="
ls -lh redis.hnp

# redis.hnp移动到ohos/hnp/arm64-v8a/redis.hnp
mkdir -p ./ohos/hnp/arm64-v8a
mv redis.hnp ./ohos/hnp/arm64-v8a/redis.hnp
echo "redis.hnp移动到ohos/hnp/arm64-v8a/redis.hnp完成! "

# 生成 HAP 文件
echo "========================================="
echo "开始生成 HAP 文件..."
echo "========================================="

# 设置构建路径变量
BUILD_DIR="$REDIS_DIR/ohos/entry/build/default"
JSON_PATH="$BUILD_DIR/intermediates/package/default/module.json"
ETS_PATH="$BUILD_DIR/intermediates/loader_out/default/ets"
OUT_PATH="$BUILD_DIR/outputs/default/entry-default-unsigned-hnp.hap"
HNP_PATH="$BUILD_DIR/outputs/default/native"
INDEX_PATH="$BUILD_DIR/intermediates/res/default/resources.index"
PACK_INFO_PATH="$BUILD_DIR/outputs/default/pack.info"
PKG_CONTEXT_PATH="$BUILD_DIR/intermediates/loader/default/pkgContextInfo.json"
HNP_SOURCE_PATH="$REDIS_DIR/ohos/hnp"
BUILD_PROFILE_PATH="$REDIS_DIR/ohos/build-profile.json5"
RESOURCES_PATH="$REDIS_DIR/ohos/entry/src/main/resources"
# 从 build-profile.json5 提取签名和证书路径
echo "从 build-profile.json5 提取签名配置..."
EXTRACT_SCRIPT="$REDIS_DIR/extract_build_profile.js"

if [ -f "$BUILD_PROFILE_PATH" ] && [ -f "$EXTRACT_SCRIPT" ]; then
    # 使用 Node.js 脚本提取路径
    SIGNATURE_PATH=$(node "$EXTRACT_SCRIPT" "$BUILD_PROFILE_PATH" profile 2>/dev/null || echo "")
    CERTIFICATE_PATH=$(node "$EXTRACT_SCRIPT" "$BUILD_PROFILE_PATH" certpath 2>/dev/null || echo "")
    
    if [ -z "$SIGNATURE_PATH" ] || [ -z "$CERTIFICATE_PATH" ]; then
        echo "警告: 无法从 build-profile.json5 提取签名配置，将跳过签名参数"
        SIGNATURE_PATH=""
        CERTIFICATE_PATH=""
    else
        echo "签名文件路径: $SIGNATURE_PATH"
        echo "证书文件路径: $CERTIFICATE_PATH"
        
        # 验证文件是否存在
        if [ ! -f "$SIGNATURE_PATH" ]; then
            echo "警告: 签名文件不存在: $SIGNATURE_PATH"
        fi
        if [ ! -f "$CERTIFICATE_PATH" ]; then
            echo "警告: 证书文件不存在: $CERTIFICATE_PATH"
        fi
    fi
else
    if [ ! -f "$BUILD_PROFILE_PATH" ]; then
        echo "警告: build-profile.json5 文件不存在: $BUILD_PROFILE_PATH"
    fi
    if [ ! -f "$EXTRACT_SCRIPT" ]; then
        echo "警告: extract_build_profile.js 脚本不存在: $EXTRACT_SCRIPT"
    fi
    SIGNATURE_PATH=""
    CERTIFICATE_PATH=""
fi

# 检查必要的文件是否存在
if [ ! -f "$APP_PACKING_TOOL" ]; then
    echo "错误: app_packing_tool.jar 未找到: $APP_PACKING_TOOL"
    exit 1
fi

if [ ! -f "$JSON_PATH" ]; then
    echo "警告: module.json 未找到: $JSON_PATH"
    echo "请确保已构建 HAP 项目"
fi

# 确保 native 目录存在
mkdir -p "$HNP_PATH"

# 复制 HNP 文件到 native 目录
if [ -d "$HNP_SOURCE_PATH" ]; then
    echo "复制 HNP 文件到 native 目录..."
    cp -r "$HNP_SOURCE_PATH"/* "$HNP_PATH/" 2>/dev/null || true
fi

# 生成 HAP 文件（HAP 模式不支持签名参数，需要在打包后单独签名）
echo "使用 app_packing_tool 生成 HAP 文件..."
java -jar "$APP_PACKING_TOOL" \
    --mode hap \
    --json-path "$JSON_PATH" \
    --ets-path "$ETS_PATH" \
    --out-path "$OUT_PATH" \
    --hnp-path "$HNP_PATH" \
    --index-path "$INDEX_PATH" \
    --pack-info-path "$PACK_INFO_PATH" \
    --pkg-context-path "$PKG_CONTEXT_PATH" \
    --force true \
    --hnp-path "$HNP_SOURCE_PATH"\
    --resources-path "$RESOURCES_PATH"

if [ $? -ne 0 ]; then
    echo "错误: HAP 文件生成失败"
    exit 1
fi

# HAP 文件签名（使用 hap-sign-tool）
echo "========================================="
echo "开始对 HAP 文件进行签名..."
echo "========================================="

# 查找签名工具
HAP_SIGN_TOOL="$OHOS_SDK_PATH/toolchains/lib/hap-sign-tool.jar"

SIGNED_HAP_PATH="${OUT_PATH%-unsigned-*}-signed.hap"
if [ "$OUT_PATH" = "$SIGNED_HAP_PATH" ]; then
    SIGNED_HAP_PATH="${OUT_PATH%.hap}-signed.hap"
fi

# 使用 hap-sign-tool 进行签名
if [ -f "$HAP_SIGN_TOOL" ] && [ -n "$SIGNATURE_PATH" ] && [ -n "$CERTIFICATE_PATH" ] && [ -f "$EXTRACT_SCRIPT" ]; then
    echo "使用 hap-sign-tool 进行签名..."
    # 从 build-profile.json5 提取签名所需的所有参数
    STORE_FILE=$(node "$EXTRACT_SCRIPT" "$BUILD_PROFILE_PATH" storeFile 2>/dev/null || echo "")
    STORE_PASSWORD=$(node "$EXTRACT_SCRIPT" "$BUILD_PROFILE_PATH" storePassword 2>/dev/null || echo "")
    KEY_ALIAS=$(node "$EXTRACT_SCRIPT" "$BUILD_PROFILE_PATH" keyAlias 2>/dev/null || echo "")
    KEY_PASSWORD=$(node "$EXTRACT_SCRIPT" "$BUILD_PROFILE_PATH" keyPassword 2>/dev/null || echo "")
    SIGN_ALG=$(node "$EXTRACT_SCRIPT" "$BUILD_PROFILE_PATH" signAlg 2>/dev/null || echo "")
    
    # 从 module.json 提取 compatibleVersion（如果存在）
    # 默认使用 API 8，如果找不到则使用默认值
    COMPATIBLE_VERSION="8"
    if [ -f "$JSON_PATH" ]; then
        # 尝试提取 minCompatibleVersionCode
        TEMP_VERSION=$(grep -o '"minCompatibleVersionCode"[[:space:]]*:[[:space:]]*[0-9]*' "$JSON_PATH" | grep -o '[0-9]*' | head -1)
        if [ -z "$TEMP_VERSION" ]; then
            # 如果没有，尝试从 minAPIVersion 提取主要版本号
            # minAPIVersion 格式如 60001021，需要提取主要版本号
            TEMP_VERSION=$(grep -o '"minAPIVersion"[[:space:]]*:[[:space:]]*[0-9]*' "$JSON_PATH" | grep -o '[0-9]*' | head -1)
            if [ -n "$TEMP_VERSION" ]; then
                # 从 60001021 提取主要版本号（第一位数字）
                # 60001021 -> 6
                COMPATIBLE_VERSION=$(echo "$TEMP_VERSION" | cut -c1)
            fi
        else
            COMPATIBLE_VERSION="$TEMP_VERSION"
        fi
    fi
    
    # 确保兼容版本不为空
    if [ -z "$COMPATIBLE_VERSION" ]; then
        COMPATIBLE_VERSION="8"
    fi
    
    if [ -n "$STORE_FILE" ] && [ -n "$STORE_PASSWORD" ] && [ -n "$KEY_ALIAS" ] && [ -n "$SIGN_ALG" ]; then
        echo "签名参数:"
        echo "  - 证书文件: $CERTIFICATE_PATH"
        echo "  - Profile文件: $SIGNATURE_PATH"
        echo "  - Keystore文件: $STORE_FILE"
        echo "  - Key别名: $KEY_ALIAS"
        echo "  - 签名算法: $SIGN_ALG"
        echo "  - 兼容版本: $COMPATIBLE_VERSION"
        
        # 检查密码是否是加密格式（DevEco Studio 加密的密码通常以 "000000" 开头）
        PASSWORD_ENCRYPTED=false
        if echo "$STORE_PASSWORD" | grep -q "^000000"; then
            PASSWORD_ENCRYPTED=true
            echo "警告: 检测到密码是加密格式（以 000000 开头）"
            echo "build-profile.json5 中的密码是加密的，hap-sign-tool 需要明文密码"
            echo ""
            echo "解决方案："
            echo "1. 在 DevEco Studio 中查看签名配置，获取明文密码"
            echo "2. 或者使用环境变量 HAP_STORE_PASSWORD 和 HAP_KEY_PASSWORD 提供明文密码"
            echo "3. 或者手动使用 hap-sign-tool 签名 HAP 文件"
            echo ""
            
            # 检查是否有环境变量提供明文密码
            if [ -n "$HAP_STORE_PASSWORD" ] && [ -n "$HAP_KEY_PASSWORD" ]; then
                echo "使用环境变量中的明文密码..."
                STORE_PASSWORD="$HAP_STORE_PASSWORD"
                KEY_PASSWORD="$HAP_KEY_PASSWORD"
                PASSWORD_ENCRYPTED=false
            else
                echo "尝试使用加密密码进行签名（可能会失败）..."
            fi
        fi
        
        # 构建签名命令（直接传递参数，避免 eval 和引号问题）
        SIGN_SUCCESS=false
        if [ -n "$KEY_PASSWORD" ]; then
            java -jar "$HAP_SIGN_TOOL" sign-app \
                -mode localSign \
                -keyAlias "$KEY_ALIAS" \
                -keyPwd "$KEY_PASSWORD" \
                -appCertFile "$CERTIFICATE_PATH" \
                -profileFile "$SIGNATURE_PATH" \
                -inFile "$OUT_PATH" \
                -signAlg "$SIGN_ALG" \
                -keystoreFile "$STORE_FILE" \
                -keystorePwd "$STORE_PASSWORD" \
                -outFile "$SIGNED_HAP_PATH" \
                -compatibleVersion "$COMPATIBLE_VERSION" \
                -signCode "1" 2>&1 | tee /tmp/hap_sign_output.log
            
            if [ ${PIPESTATUS[0]} -eq 0 ] && [ -f "$SIGNED_HAP_PATH" ]; then
                SIGN_SUCCESS=true
            fi
        else
            java -jar "$HAP_SIGN_TOOL" sign-app \
                -mode localSign \
                -keyAlias "$KEY_ALIAS" \
                -appCertFile "$CERTIFICATE_PATH" \
                -profileFile "$SIGNATURE_PATH" \
                -inFile "$OUT_PATH" \
                -signAlg "$SIGN_ALG" \
                -keystoreFile "$STORE_FILE" \
                -keystorePwd "$STORE_PASSWORD" \
                -outFile "$SIGNED_HAP_PATH" \
                -compatibleVersion "$COMPATIBLE_VERSION" \
                -signCode "1" 2>&1 | tee /tmp/hap_sign_output.log
            
            if [ ${PIPESTATUS[0]} -eq 0 ] && [ -f "$SIGNED_HAP_PATH" ]; then
                SIGN_SUCCESS=true
            fi
        fi
        
        if [ "$SIGN_SUCCESS" = true ]; then
            echo "HAP 文件签名成功: $SIGNED_HAP_PATH"
            OUT_PATH="$SIGNED_HAP_PATH"
        else
            echo "错误: HAP 文件签名失败"
            if [ "$PASSWORD_ENCRYPTED" = true ]; then
                echo ""
                echo "原因: build-profile.json5 中的密码是加密的"
                echo "解决方法："
                echo "  1. 设置环境变量（在运行脚本前）："
                echo "     export HAP_STORE_PASSWORD='你的明文keystore密码'"
                echo "     export HAP_KEY_PASSWORD='你的明文key密码'"
                echo "  2. 或者手动签名 HAP 文件："
                echo "     java -jar $HAP_SIGN_TOOL sign-app -mode localSign ..."
                echo "  3. 或者使用 DevEco Studio 构建项目（会自动处理加密密码）"
            else
                echo "请检查签名配置和文件路径"
                echo "签名工具输出已保存到: /tmp/hap_sign_output.log"
            fi
        fi
    else
        echo "警告: 无法提取完整的签名配置信息"
        echo "缺少的参数:"
        [ -z "$STORE_FILE" ] && echo "  - storeFile"
        [ -z "$STORE_PASSWORD" ] && echo "  - storePassword"
        [ -z "$KEY_ALIAS" ] && echo "  - keyAlias"
        [ -z "$SIGN_ALG" ] && echo "  - signAlg"
    fi
else
    if [ ! -f "$HAP_SIGN_TOOL" ]; then
        echo "警告: hap-sign-tool.jar 未找到: $HAP_SIGN_TOOL"
    fi
    if [ -z "$SIGNATURE_PATH" ] || [ -z "$CERTIFICATE_PATH" ]; then
        echo "警告: 无法从 build-profile.json5 提取签名配置"
    fi
    if [ ! -f "$EXTRACT_SCRIPT" ]; then
        echo "警告: extract_build_profile.js 脚本不存在"
    fi
    echo "生成的 HAP 文件未签名，请手动签名或使用 DevEco Studio 构建项目"
fi

echo "========================================="
echo "HAP 文件生成完成！"
echo "HAP 文件: $OUT_PATH"
echo "========================================="
ls -lh "$OUT_PATH" 2>/dev/null || echo "HAP 文件路径: $OUT_PATH"
