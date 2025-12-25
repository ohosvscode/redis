# Redis HNP 编译修改说明

本文档记录了为支持 HarmonyOS Native Package (HNP) 编译而对 Redis 源代码所做的修改。

## 修改的文件

### 1. 新增文件

- **`src/pthread_compat.h`** - pthread 兼容层，为 musl libc 提供线程取消功能的空实现
- **`build_hnp.sh`** - Redis HNP 编译脚本
- **`HNP_BUILD_GUIDE.md`** - HNP 编译指南文档
- **`examples/hnp_example/`** - HNP 编译示例项目

### 2. 修改的文件

#### `src/threads_mngr.c`
- **问题**: `_Atomic` 类型不能直接用 `NULL` 进行静态初始化
- **修改**: 将静态初始化改为运行时初始化，在 `ThreadsManager_init()` 函数中初始化原子变量

#### `src/setproctitle.c`
- **问题**: `program_invocation_name` 是 GNU libc 扩展，在 musl libc 中不可用
- **修改**: 添加 `__GLIBC__` 条件编译，只在 GNU libc 环境下使用这些变量

#### `src/server.h`
- **修改**: 添加 `#include "pthread_compat.h"` 以包含 pthread 兼容层

#### `src/server.c`
- **修改**: 添加 `#include "pthread_compat.h"`（通过 server.h 间接包含）

## 查看差异

使用以下命令查看与上游的差异：

```bash
# 查看所有修改的文件
git diff 8.4.0 --name-only

# 查看源代码修改的详细差异
git diff 8.4.0 src/pthread_compat.h src/threads_mngr.c src/setproctitle.c src/server.h

# 查看统计信息
git diff 8.4.0 --shortstat
```

## 修改原因

这些修改是为了使 Redis 能够在 OpenHarmony (musl libc) 环境下编译：

1. **musl libc 兼容性**: musl libc 不支持某些 GNU libc 扩展功能
2. **线程取消**: musl libc 不支持 pthread 取消功能，需要提供兼容实现
3. **原子变量初始化**: C11 `_Atomic` 类型的初始化限制

## 兼容性说明

- ✅ 这些修改不影响在标准 Linux (glibc) 环境下的编译
- ✅ 修改使用条件编译，只在需要时生效
- ✅ 不影响 Redis 的核心功能

