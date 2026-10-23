# Lingdong Photo 4.0.0 — Public Edition / 公开版本

版本：4.0.0，Build 202649。

这个目录是可构建的社区版本，不是完整官方 App 的源码镜像。它保留本机照片创作、票根、相簿、邮票、明信片及相关工具，并采用既有公开版本的非商业占位实现和占位图片。4.0.0 的灵动来信界面、编辑器、信匣、搜索、拆信动效、完整阅读器及服务端实现不包含在此目录中。

## 公开适配

- 应用直接进入 `ContentView`，不链接私有来信模块。
- 设置页提供公开范围说明，不能切换到未发布的来信功能。
- 引导页沿用已经公开的普通创作引导，并说明当前版本范围。
- `Signing.xcconfig` 采用示例 Bundle ID，不包含生产服务地址或个人签名配置；App Clip 与扩展从这些变量派生标识符。
- 移除来信服务使用的 Apple 登录权限、Face ID 用途和本地 HTTP 调试例外。主应用隐私清单描述本公开版本；正式 App 的收集行为必须以其对应政策为准。
- 保留 4.0.0 普通创作的界面适配、壁纸渲染及其他公开改进。三份 README 的功能和隐私说明适用于本公开版本的本机创作范围。

## 加密透明资料

[Transparency/README.md](Transparency/README.md) 描述客户端加密、密码包装、密文包和主动举报披露。独立示例使用虚构文本，提供离线 Swift / Web Crypto 互操作验证，不依赖账号或服务端。验证范围为参考算法与协议，不包含正式 App 二进制和线上部署。

## 构建

在 Xcode 中打开 `lingdongzhaopian/lingdongzhaopian.xcodeproj`，选择 `lingdongzhaopian` Scheme。模拟器构建不需要账户；真机签名按 `Config/Signing.local.example.xcconfig` 配置标识符和 Team。本地签名配置由 `.gitignore` 排除。工程可从本目录独立构建。

命令行示例（在此目录运行，替换输出目录）：

```sh
xcodebuild -project lingdongzhaopian/lingdongzhaopian.xcodeproj \
  -scheme lingdongzhaopian -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/lingdong-public-derived-data CODE_SIGNING_ALLOWED=NO build
```

公开源码按仓库 `LICENSE` 的 AGPL-3.0-only 授权。既有字体保留原许可证，品牌与图片边界见 `TRADEMARKS.md`。

---

The Public Edition of Lingdong Photo 4.0.0 (Build 202649) includes local photo-creation tools, public commercial placeholders, and standalone encryption transparency materials. Letter UI, business logic, the full reader and server implementation are excluded. The project builds independently. See the transparency document for protocol details, voluntary report disclosure and offline checks. Existing source and third-party licenses remain in force.
