cmake_minimum_required(VERSION 3.10)
project(my_hnp_project)

# 设置 OpenHarmony SDK 路径
set(OHOS_SDK_PATH "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony")
set(CMAKE_C_COMPILER "${OHOS_SDK_PATH}/native/llvm/bin/aarch64-unknown-linux-ohos-clang")
set(CMAKE_CXX_COMPILER "${OHOS_SDK_PATH}/native/llvm/bin/aarch64-unknown-linux-ohos-clang++")

# 设置编译选项
set(CMAKE_C_FLAGS "--target=aarch64-unknown-linux-ohos --sysroot=${OHOS_SDK_PATH}/native/sysroot")
set(CMAKE_CXX_FLAGS "--target=aarch64-unknown-linux-ohos --sysroot=${OHOS_SDK_PATH}/native/sysroot")

# 添加可执行文件
add_executable(my_hnp_app main.c)

# 设置输出目录
set_target_properties(my_hnp_app PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

