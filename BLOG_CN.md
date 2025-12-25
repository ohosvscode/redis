# 把 Redis 搬到鸿蒙 PC 上，我踩了这些坑

最近在折腾鸿蒙 PC 开发，突发奇想：能不能把 Redis 也搞上去？说干就干，结果踩了一堆坑，写下来给后来人避避雷。

## 为啥要干这事？

其实没啥高大上的理由，就是好奇。鸿蒙 PC 刚出来，生态还比较荒，想看看能不能把常用的开源软件跑起来。Redis 作为内存数据库，用的人多，如果能移植成功，应该挺有用的。

而且我一直觉得跨平台移植挺有意思的，每次看到代码在另一个平台上跑起来，都有种"我做到了"的感觉。

## 第一步：装 DevEco Studio 和 OpenHarmony SDK

说干就干，第一步当然是准备环境。鸿蒙开发需要 DevEco Studio 和 OpenHarmony SDK。

我直接去官网下了 DevEco Studio，安装过程倒是挺顺利的。装完后打开，发现需要配置 SDK。默认路径是：

```
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony
```

我一开始还以为 SDK 会自动下载，结果发现得手动配置。在 DevEco Studio 的设置里找到 SDK 配置，选好路径，然后等它下载。这个过程有点慢，我趁机去泡了杯咖啡。

SDK 下完后，我检查了一下关键工具：

- `native/llvm/bin/aarch64-unknown-linux-ohos-clang` - 编译器
- `native/llvm/bin/llvm-ar` - 归档工具
- `native/sysroot` - 系统根目录
- `toolchains/hnpcli` - HNP 打包工具

确认这些文件都在，我才放心继续。如果这些工具找不到，后面编译肯定要出问题。

顺便说一句，如果你的 SDK 路径不一样，记得改一下脚本里的路径。我一开始路径写错了，编译的时候报错说找不到编译器，我还以为是 SDK 没装好，结果是自己路径写错了，白折腾了半天。

## 第一次编译：想得太简单了

刚开始我以为改个编译器路径就完事了，结果被现实狠狠打脸。

第一个错误就让我傻眼了：

```
undefined reference to `pthread_setcancelstate'
```

我：？？？这啥玩意儿？

查了半天才知道，musl libc 根本不支持 pthread 的取消功能。我当时就懵了，这怎么搞？Redis 的代码里用到了这个函数，但目标平台不支持。

说实话，那一刻我有点想放弃。但转念一想，来都来了，再试试吧。

## 查资料查到怀疑人生

为了解决这个问题，我开始疯狂查资料。Stack Overflow、GitHub Issues、各种技术博客翻了个遍。

发现 musl libc 和 glibc 的差异比我想象的大。musl 追求简洁，很多 GNU 扩展都不支持。比如 `program_invocation_name` 这个变量，glibc 里有，musl 里就没有。

Redis 的代码里用这个变量来设置进程标题，我只好用条件编译绕过去：

```c
#if defined(__GLIBC__)
    program_invocation_name = tmp;
#endif
```

虽然有点丑，但能跑就行。

## _Atomic 初始化：最坑的一个

这个问题真的把我搞崩溃了。

Redis 代码里有这么一行：

```c
static redisAtomic run_on_thread_cb g_callback = NULL;
```

编译报错：`initializer element is not a compile-time constant`

我：？？？NULL 不是常量吗？

查了 C11 标准才知道，`_Atomic` 类型不能用这种方式初始化。我试了好几种方法都不行，最后发现只能在运行时初始化：

```c
static redisAtomic run_on_thread_cb g_callback;

void ThreadsManager_init(void) {
    atomicSet(g_callback, NULL);
}
```

就这么一个小改动，我折腾了大半天。C 语言有时候真的让人抓狂。

## 写兼容层：没办法的办法

既然 musl 不支持 pthread 取消，那我就自己写个假的。

创建了 `pthread_compat.h`，里面就是几个空函数：

```c
static inline int pthread_cancel(pthread_t thread) {
    (void)thread;
    return 0; // 假装成功了
}
```

虽然这些函数啥都不干，但至少能让代码编译通过。我知道这不是最优解，但现阶段够用了。Redis 在大多数场景下也用不到线程取消，所以问题不大。

## 写编译脚本：终于有点样子了

手动编译了几次后，我意识到得写个脚本，不然每次都要敲一堆命令，太麻烦了。

写 `build_hnp.sh` 的时候，我一边写一边改，试了好几次才把参数调对。特别是那些编译标志，每个都是试出来的：

```bash
export CFLAGS="--target=aarch64-unknown-linux-ohos --sysroot=$OHOS_SYSROOT -D__MUSL__ -DNO_PTHREAD_CANCEL"
```

`-DNO_PTHREAD_CANCEL` 这个宏是我自己加的，用来启用兼容层。看起来简单，但找到这个方法花了不少时间。

## 终于编译成功了

当看到 `redis.hnp` 文件生成的时候，我差点从椅子上跳起来。

虽然只是第一步（还没在真机上测试），但至少证明这条路能走通。文件大小 4.4MB，比原版大一点，但考虑到包含了所有依赖，还算可以接受。

不过说实话，我现在也不知道在真机上能不能跑起来。可能还有一堆运行时问题等着我。

## 一些乱七八糟的想法

这次折腾让我明白了几件事：

1. **平台差异真的烦人**。glibc 和 musl libc 看起来差不多，用起来差别还挺大。每次遇到这种问题，我都想骂人，但骂完还得继续搞。

2. **兼容性代码虽然丑，但有用**。那些 `#ifdef` 满天飞的代码确实不好看，但能让程序在不同平台上跑，这就是它的价值。

3. **查资料是个技术活**。有时候一个问题要翻几十个网页才能找到答案，而且很多答案都是错的或者过时的。这种时候真的考验耐心。

4. **开源社区真香**。遇到问题的时候，看看别人是怎么解决的，能少走很多弯路。虽然这次没直接抄代码，但思路都是参考别人的。

## 接下来要干啥

虽然编译成功了，但我知道这还远远不够：

- 得在真机上跑一下，看看有没有运行时错误
- 性能怎么样，会不会比 Linux 版本慢很多
- TLS 和模块功能现在都禁用了，以后可能得加回来
- 文档也得写，不然别人用起来不方便

不过现在先这样吧，至少能编译出来了。剩下的问题慢慢解决。

## 最后

这次折腾花了不少时间，但还挺有意思的。虽然过程中各种抓狂，但最后看到成果的时候，还是有点成就感的。

代码已经扔到 GitHub 上了，虽然还有很多不完善的地方，但至少能用了。如果有人也想在鸿蒙 PC 上跑 Redis，可以参考一下。

当然，如果遇到问题，欢迎提 Issue。如果觉得哪里可以改进，也欢迎提 PR。

---

项目地址：https://github.com/ohosvscode/redis

如果这篇文章对你有帮助，或者你也踩过类似的坑，欢迎在评论区聊聊。
