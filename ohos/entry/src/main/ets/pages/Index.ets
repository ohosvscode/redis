import { deviceInfo } from '@kit.BasicServicesKit';

@Entry
@Component
struct Index {
  @State message: string = 'Hello World';

  build() {
    Column() {
      Image($r('app.media.redis_logo'))
        .size({ width: 300, height: 100 })
        .margin({ bottom: 20 })

      Text("Redis 8.4.0")
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 10 })

      Text("Redis已安装到您的设备，我们提供以下两个命令：")
      Divider().margin({ top: 5, bottom: 5 })
      Text("redis-server: 启动redis服务")
      Text("redis-cli: 打开Redis CLI")
      if (deviceInfo.deviceType === '2in1') {
        Divider().margin({ top: 5, bottom: 5 })
        Text("您可以打开系统自带终端运行")
      }
      Hyperlink("https://github.com/ohosvscode/redis", "点击打开 Github 仓库")
        .margin({ top: 5 })
    }.justifyContent(FlexAlign.Center)
    .width("100%")
    .height("100%")
    .padding({ top: 14, left: 20, right: 20 })
  }
}