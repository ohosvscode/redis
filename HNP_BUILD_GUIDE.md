# Redis HNP 编译指南

本指南说明如何将 Redis 编译为 HarmonyOS Native Package (HNP) 格式。

## 文件结构

```
redis-8.4.0/
├── build_hnp.sh              # Redis HNP 编译脚本（主脚本）
├── redis.hnp                 # 编译生成的 Redis HNP 包
├── examples/
│   └── hnp_example/          # HNP 编译示例项目
│       ├── main.c            # 示例源代码
│       ├── build.sh          # 示例编译脚本
│       ├── CMakeLists.txt    # CMake 配置
│       └── my_hnp_project.hnp # 示例 HNP 包
├── src/
│   ├── pthread_compat.h      # pthread 兼容层（musl libc 支持）
│   ├── threads_mngr.c        # 已修改（修复 _Atomic 初始化）
│   ├── setproctitle.c        # 已修改（musl libc 兼容）
│   └── server.h              # 已修改（包含 pthread_compat.h）
└── hnp_package/              # 打包临时目录
    ├── redis-server
    ├── redis-cli
    └── redis.conf
```

## 快速开始

### 编译 Redis HNP

```bash
cd /Users/naily/Documents/redis-8.4.0
./build_hnp.sh
```

编译完成后会生成 `redis.hnp` 文件。

### 运行示例项目

```bash
cd examples/hnp_example
./build.sh
```

## 编译要求

1. **OpenHarmony SDK**: 位于 `/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony`
2. **编译器**: OpenHarmony SDK 自带的 LLVM/Clang 工具链
3. **打包工具**: `hnpcli` (包含在 SDK 中)

## 修改说明

为了在 OpenHarmony (musl libc) 环境下编译，对以下文件进行了修改：

1. **src/pthread_compat.h** (新建)
   - 提供 pthread 取消功能的兼容实现
   - musl libc 不支持线程取消，提供空实现

2. **src/threads_mngr.c**
   - 修复 `_Atomic` 类型的初始化问题
   - 将静态初始化改为运行时初始化

3. **src/setproctitle.c**
   - 修复 `program_invocation_name` 问题
   - 添加 `__GLIBC__` 条件编译

4. **src/server.h**
   - 包含 `pthread_compat.h` 头文件

## 编译选项

- `BUILD_TLS=no` - 禁用 TLS 支持
- `BUILD_WITH_MODULES=no` - 禁用模块支持
- `MALLOC=libc` - 使用 libc 内存分配器
- `DISABLE_WERRORS=yes` - 禁用将警告视为错误

## 输出文件

- `redis.hnp` - Redis HNP 包（约 4.4MB）
- `src/redis-server` - ARM64 ELF 可执行文件（约 9.3MB）
- `src/redis-cli` - Redis 客户端（约 1.2MB）

## 注意事项

1. **架构兼容性**: 当前编译的是 ARM64 (aarch64) 架构
2. **系统要求**: 需要在 HarmonyOS 设备上运行
3. **功能限制**: TLS 和模块功能已禁用
4. **测试**: 建议在 HarmonyOS 设备上测试运行

## 相关资源

- [OpenHarmony 官方文档](https://gitee.com/openharmony/docs)
- [HarmonyOS 开发者文档](https://developer.harmonyos.com/)

