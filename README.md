# 灵动照片

一款面向 iOS 与 Android 的本地照片创作工具。iOS 版本使用 SwiftUI，Android 版本使用 Kotlin 与 Jetpack Compose；两个版本都可以从照片中提取感知色彩、识别画面内容、读取真实拍摄信息，并生成卡片、色盘、手帐、印章、壁纸与隐私遮挡作品。iOS 可以从系统照片操作列表或快捷指令进入处理流程，Android 可以通过系统照片选择器或分享菜单导入单张及多张照片。

> [!IMPORTANT]
> **App Store 正式版状态：** 正式版当前已提交审核，正在等待 Apple 审核结果。审核通过并正式上架后，本 README 将同步更新 App Store 下载入口与发布信息。

> **TestFlight 公共测试：** [立即安装并体验“灵动照片”](https://testflight.apple.com/join/p3gtANmj)

> **Android 安装包：** [下载已签名 APK](https://locallens.cn/LingdongPhoto-Android.apk)

> 完全免费，无订阅、无内购、无广告。照片识别、色彩分析与作品渲染均在设备上完成。

## 界面预览

<p align="center">
  <img src="./灵动卡片_new.png?v=3" alt="灵动卡片" width="23%">
  <img src="./琉璃色盘_new.png?v=3" alt="琉璃色盘" width="23%">
  <img src="./气泡印章_new.png?v=3" alt="气泡印章" width="23%">
  <img src="./隐私马赛克.png?v=3" alt="隐私马赛克" width="23%">
</p>

| 灵动卡片 | 琉璃色盘 | 气泡印章 | 隐私马赛克 |
| :---: | :---: | :---: | :---: |
| 根据画面生成文案并保留拍摄时间 | 六种代表色、色值与整图占比 | 照片、文案和真实 EXIF 组合排版 | 手动涂抹或本机智能识别并遮挡隐私内容 |

## Android 版本

Android 版本使用 Kotlin 与 Jetpack Compose 编写，支持 Android 14 及以上系统。界面与交互针对 Android 设备重新实现，照片处理流程不依赖项目服务器，应用清单也不申请网络权限。

- 提供灵动卡片、琉璃色盘、一键手帐、气泡印章、色谱壁纸和隐私马赛克六种创作模式
- 支持系统照片选择器，也可以从其他应用的分享菜单接收单张或多张照片
- 支持原图、1:1、3:4、4:5、9:16 与 16:9 六种画幅，以及卡片、手帐和印章的多种模板
- 使用 OKLab 感知色彩空间与带权 K-Means 提取最多六种代表色，显示 HEX 或文学颜色名及整图占比
- 琉璃色盘提供经典浮动与紧凑横排布局；玻璃面板使用 AGSL 运行时着色器实现折射和边缘光学效果
- 使用 Android ML Kit 在本机完成画面分类，并辅助识别人脸、车牌、二维码与敏感文字
- 读取照片中的设备、镜头、光圈、快门、ISO、焦距、拍摄时间与 GPS 元数据
- 支持读取、预览并向系统相册保存 Motion Photo 动态作品；隐私马赛克只导出处理后的静态画面
- 支持 JPEG、PNG 与 HEIC，以及 1080P、2K 和最高 6000 像素宽的原图级输出
- 支持保存到系统相册、导出到文件和系统分享，并可完整保留元数据、移除 GPS 或执行隐私净化
- 导出琉璃色盘时使用 GPU 画布渲染，使保存结果保留编辑界面中的玻璃效果

## 为什么做这个项目

最初只是想看看，这类看起来精致的照片小工具究竟有多复杂，于是参考公开可见的产品交互，用 SwiftUI 从零做了一次学习性质的复刻。没有使用或反编译任何第三方应用的源代码、素材与私有资源。

写着写着，项目已经不再只是“照着做一个界面”：它加入了 OKLab 感知色彩、加权 K-Means、色彩占比、Apple Vision 本机识图、分类文案库、真实 EXIF、Live Photo 动态导出、多图手帐、隐私马赛克、照片操作扩展、App Shortcuts、导出中心和可编辑交互。Android 版本随后使用 Kotlin 与 Jetpack Compose 独立实现同一套核心创作流程，并使用 ML Kit 与 Motion Photo 适配 Android 平台能力。

至于价格，市面上确实有功能相近的小工具采用 **¥12/月** 或 **¥168 买断**。定价当然是每位开发者的自由，只是对这种体量的工具，我更愿意把实现过程公开，让感兴趣的人能看懂、修改和继续完善。

看到“¥12/月”时，我的第一反应大概是：这是在给照片提取色彩，还是在给钱包降低饱和度？

> **彩蛋：** 本项目还给色盘增加了每种颜色占整张图片的百分比。照这个思路，是不是应该卖 ¥268？——当然不会。百分比只是功能，不是价格乘数。

以上只是针对产品定价方式的轻松吐槽，不针对任何具体开发者，也不否认设计、维护和上架本身所需要的劳动。

## iOS 版本功能

### 灵动卡片

- 根据画面内容与色彩自动生成标题
- 显示真实拍摄时间或照片位置信息
- 根据主体色及其画面占比生成协调的同色系文字区
- 自动选择深色或浅色文字，标题与小字的目标对比度不低于 7:1
- 经典、留白、沉浸三种作品模板
- 支持拖拽构图、双指缩放
- 点击文字直接编辑
- 滑动切换字体与调整文字大小
- 晃动设备恢复初始构图

### 更多画幅与模板

- 支持原图、1:1、3:4、4:5、9:16 与 16:9 六种画幅
- “原图”会跟随照片的实际比例
- 灵动卡片和气泡印章可切换经典、留白、沉浸模板
- 一键手帐可切换自动拼贴、杂志主图、纵向胶卷模板
- 琉璃色盘在长画幅中保持稳定宽度，只沿长边增加可用空间

### 琉璃色盘

- 从整张照片提取六种代表色
- 显示 HEX 色值，或使用包含 76 个参考色的文学颜色目录按 OKLab 感知距离命名
- 显示每种颜色在整张照片中的百分比，占比合计为 100%
- 经典浮动、紧凑横排、底部悬浮三种布局
- 支持拖动色盘位置
- 导出时可保留液态玻璃或兼容磨砂效果

### 一键手帐

- 一次选择 1～5 张照片
- 根据照片数量自动切换拼图布局
- 支持自动拼贴、杂志主图与纵向胶卷三种布局
- 可单独选择、替换、删除、拖拽排序每张照片，并分别调整缩放与位置
- 系统识图后生成对应文案与 Emoji
- 支持“换一组”，同一类别可组合超过千组内容
- 文案与 Emoji 可手动编辑
- 根据背景亮度自动调整文字对比度

### 气泡印章

- 将照片、文案、主色与拍摄参数组合成摄影印章
- 读取设备、镜头、光圈、快门、ISO 与焦距
- 支持调整图片、字体、文字大小和气泡比例
- 可独立关闭设备信息或气泡装饰

### 色谱壁纸

- 根据照片主色生成渐变色谱
- 适配当前设备尺寸
- 支持生成过程动画与减弱动态效果

### 隐私马赛克

- 在“隐私遮挡模式”中手动涂抹或擦除马赛克，退出后恢复照片构图手势
- 使用 Apple Vision 在本机识别人脸、车牌、二维码和敏感文字
- 每个智能识别区域都是独立遮罩，点击可以关闭，再次点击即可恢复
- 支持撤销操作以及调节马赛克强度和颗粒大小
- 对 Live Photo 仅提供静态导出，避免未处理的动态帧泄露隐私
- 导出时可以选择移除 GPS 位置信息

> [!IMPORTANT]
> 智能识别仅作为辅助，可能出现遗漏或误判。涉及身份证件、账号、地址等高敏感内容时，请在导出前逐项检查，并使用手动涂抹补充遮挡。

### 导出中心

- 可保存到系统相册、导出到“文件”或打开系统分享面板
- 支持 JPEG、PNG 与 HEIC
- 支持 1080P、2K 与原图级输出；原图级最高限制为 6000 像素宽
- 可完整保留元数据、只移除 GPS，或执行隐私净化并移除 GPS、设备、镜头和原始拍摄时间
- Live Photo 保存到系统相册时可保留动态资源；文件与系统分享导出静态成品

### 系统照片操作与快捷指令

- 在系统照片的纵向操作列表中选择“用灵动照片打开”，可在液态玻璃扩展界面选择六种创作模式并继续到主应用
- 扩展会显示实况或静态标记，界面背景、面板和按钮自动跟随系统深色或浅色模式
- 主应用与扩展通过 App Group 传递最多 5 张照片、所选模式和 Live Photo 配对视频
- 提供“提取照片色彩”“净化照片元数据”“生成色谱壁纸”三个 App Shortcut，均可在不打开主应用的情况下完成本机处理

## iOS 本机智能文案

项目使用 Apple Vision 在设备上分析照片，并根据人像、亲友、猫狗、鸟类、昆虫、花园、森林、山水、海滩、天空、日落、城市、建筑、街道、夜景、美食、咖啡、旅行、运动、文字截图等 34 类语义生成内容。

每个类别分别提供中文标题片段、英文短句与 Emoji 组合。图片签名保证同一张照片首次生成时结果稳定，“换一组”则会得到新的类别内组合。蝴蝶、蜜蜂、瓢虫等细分类还会优先匹配对应 Emoji，而不是只根据主色随便挑选。

识别使用 `VNClassifyImageRequest`、`VNDetectFaceRectanglesRequest` 与 `VNRecognizeTextRequest`，不会把照片上传到项目作者的服务器。若系统识别暂时不可用，会使用照片主色生成兜底文案，不影响作品导出。

## 色彩提取

“琉璃色盘”不是从固定模板中挑颜色：

1. 缩放并采样整张图片
2. 将 RGB 转换到 OKLab 感知色彩空间
3. 使用带权 K-Means 聚类代表色
4. 按感知距离把采样点分配到最近的颜色簇
5. 按像素权重计算各颜色占比
6. 将小数舍入误差回补至最大颜色簇，确保六项合计为 100%

相比直接在 RGB 空间取平均值，OKLab 更接近人眼对颜色差异的感知。

文学颜色名同样在 OKLab 空间中寻找最近参考色。当前目录包含 76 个名称，覆盖不同明度、色相和饱和度，并保留适合阅读与创作的离散命名方式。

## iOS 液态玻璃

- iOS 26 使用系统原生 Liquid Glass API
- iOS 18 自动切换为兼容磨砂材质
- 按钮支持按压缩放、回弹和触觉反馈
- 设置页、编辑弹窗、色盘面板和导出作品使用统一玻璃语言
- 设置面板、导出中心、系统选图器和照片操作扩展会跟随系统深色或浅色模式；主编辑界面继续保留既有视觉设计
- “减少动态效果”开启后会跳过非必要动画

## iOS 照片与 Live Photo

- 主应用使用系统 PhotosPicker 读取用户主动选择的照片；普通选图流程不需要遍历整个照片库
- 从原始数据读取真实 EXIF、TIFF 与 GPS 字段
- 支持读取 Live Photo 配对视频资源
- 从系统照片操作扩展导入时，静态帧、动态片段和所选模式会通过 App Group 原样交接给主应用
- 从照片操作扩展导入 Live Photo 时，会在已获授权的照片范围内精确匹配所选原片并恢复配对视频
- 选择 Live Photo 后，除“隐私马赛克”外均会保留动态资源
- 点击照片区域左上角的实况图标可播放一次，播放结束后自动停在静态画面
- 动态导出会逐帧合成作品，并写入匹配的资源标识
- 实况关键帧与动态帧统一转换至标准动态范围，避免 HDR 内容导致界面和文字明暗异常
- 静态导出尽可能保留原照片元数据
- 一键手帐可组合多张 Live Photo 的动态内容

缺少的拍摄参数会保持为空，不会用固定相机型号、光圈或 ISO 冒充真实数据。

## 隐私

- 不需要账户
- 不包含广告或第三方分析 SDK
- 不收集用户照片、创作内容或设备标识
- iOS 使用 Apple Vision，Android 使用 ML Kit；识别、色彩计算和渲染都在本机执行
- iOS 主应用与照片操作扩展通过 App Group 交接内容；Android 只读取照片选择器或分享菜单中由用户主动授予的内容 URI
- 仅在用户操作保存时写入系统相册
- iOS 在需要显示地名时可能调用 Apple 的系统地理编码服务；Android 版本不包含地图功能，也不申请网络权限

### 为什么坚持本地处理

提取颜色、读取 EXIF、识别画面和生成作品，手机本身已经能够完成，根本不需要把照片元数据、粗略位置或设备标识符上传到开发者服务器。

有的开发者选择传输“遥测”数据，其中包括设备标识和照片中的粗略地理位置。而灵动照片不以反作弊或免费额度为理由收集 IDFV、广告标识符或其他设备标识，也不设置每日使用次数：提取颜色不需要云端，生成卡片不需要设备追踪，完全免费更不需要每日配额。

我们更愿意把选择权交还给用户。iOS 与 Android 的设置中都提供“显示应用标题”选项：即使不会自行编译，也可以隐藏编辑界面左上角的“灵动照片”，且不影响导出作品。工具装在你的设备上，应当服务于你的创作，而不是把你变成它的数据或广告位。

> 能在本机完成的事情，就应该留在本机。

## 系统要求

### iOS

- iOS 18.0+
- Xcode 26.0+（编译 iOS 26 原生 Liquid Glass 代码需要对应 SDK）
- Swift 5 语言模式
- iPhone；当前界面以竖屏体验为主

### Android

- Android 14+（API 34+）
- Android Studio 与 Android SDK 36
- Android Gradle Plugin 8.13.2、Gradle 8.13、Kotlin 2.0.21
- JDK 17+；应用字节码目标为 Java 11
- 手机或折叠屏设备；当前界面以竖屏体验为主

## 构建

### iOS

1. 克隆仓库：

   ```bash
   git clone https://github.com/LocalLens-Project/LingdongPhoto.git
   cd LingdongPhoto
   ```

2. 使用 Xcode 打开工程：

   ```bash
   open lingdongzhaopian/lingdongzhaopian.xcodeproj
   ```

3. 创建只在本机使用的签名配置：

   ```bash
   cp lingdongzhaopian/Config/Signing.local.example.xcconfig \
      lingdongzhaopian/Config/Signing.local.xcconfig
   ```

4. 在 `Signing.local.xcconfig` 中填写以下值：

   ```xcconfig
   DEVELOPMENT_TEAM = YOUR_TEAM_ID
   PRODUCT_BUNDLE_IDENTIFIER = com.example.yourapp
   SHARE_EXTENSION_BUNDLE_IDENTIFIER = com.example.yourapp.ShareExtension
   APP_GROUP_IDENTIFIER = group.com.example.yourapp
   ```

5. 在开发者账户中创建对应 App Group，并为主应用与 `LingdongShareExtension` 两个 Target 启用同一个 App Group。扩展标识必须与主应用标识不同。

6. 选择一台 iOS 18+ 模拟器或真机并运行；Archive 也会自动使用这份本地签名配置，并将照片操作扩展嵌入主应用。

### Android

1. 进入 Android 工程：

   ```bash
   cd Android/lingdongzhaopian
   ```

2. 使用 Gradle Wrapper 构建 Debug 安装包：

   ```bash
   ./gradlew assembleDebug
   ```

3. 构建结果位于：

   ```text
   app/build/outputs/apk/debug/app-debug.apk
   ```

4. 如需构建签名 Release，请在工程根目录创建只在本机使用的 `keystore.properties`，并把密钥文件放入 `signing/`。这两个路径已经被 Android 工程的 `.gitignore` 排除；配置完成后运行：

   ```properties
   storeFile=signing/your-release.jks
   storePassword=YOUR_STORE_PASSWORD
   keyAlias=YOUR_KEY_ALIAS
   keyPassword=YOUR_KEY_PASSWORD
   ```

   ```bash
   ./gradlew assembleRelease
   ```

项目提供的已签名版本可以直接从 [Android 下载地址](https://locallens.cn/LingdongPhoto-Android.apk) 获取。

## iOS 相册权限

应用需要以下权限说明：

- 应用内选图：由系统 PhotosPicker 提供用户主动选择的内容，不需要授予整个照片库的读取权限
- 从系统照片操作扩展导入静态照片：通常可直接读取系统提供的静态文件
- 从系统照片操作扩展导入 Live Photo：需要照片读取授权来匹配所选原片并恢复配对视频；“有限访问”适用于已包含在授权范围内的原片，完全访问可处理整个照片库中的所选原片
- 添加照片：把生成的静态作品或 Live Photo 保存到系统相册

照片读取授权仅用于恢复用户主动选择的 Live Photo 动态资源，照片不会上传。

## Android 照片权限

- 应用内选图使用 Android 系统照片选择器，不需要申请整个照片库的读取权限
- 从其他应用分享照片时，只读取系统临时授予访问权的内容 URI
- 保存作品通过 MediaStore 写入系统相册，不申请旧版外部存储权限
- Android 清单只声明振动权限，用于交互反馈；不声明网络、定位、相机或麦克风权限

照片、Motion Photo 动态片段与导出缓存只在本机处理，应用不会把它们上传到项目服务器。

## 项目结构

```text
.
├── README.md                     # 项目说明
├── LICENSE
├── TRADEMARKS.md
├── 灵动卡片_new.png
├── 琉璃色盘_new.png
├── 气泡印章_new.png
├── 隐私马赛克.png
├── lingdongzhaopian/
│   ├── Config/
│   │   ├── App-Info.plist
│   │   ├── App.entitlements
│   │   ├── ShareExtension-Info.plist
│   │   ├── ShareExtension.entitlements
│   │   ├── Signing.xcconfig
│   │   └── Signing.local.example.xcconfig
│   ├── LingdongShareExtension/
│   │   └── ShareViewController.swift
│   ├── Validation/
│   │   ├── LiteraryColorCatalogValidation.swift
│   │   └── MotionCardColorThemeValidation.swift
│   ├── lingdongzhaopian.xcodeproj
│   └── lingdongzhaopian/
│       ├── AppModel.swift
│       ├── ArtworkCanvas.swift
│       ├── ArtworkExporter.swift
│       ├── ContentView.swift
│       ├── DisplayImageNormalizer.swift
│       ├── ExportCenter.swift
│       ├── JournalEditorControls.swift
│       ├── LiteraryColorCatalog.swift
│       ├── LiquidGlass.swift
│       ├── LivePhotoPreview.swift
│       ├── MotionCardColorTheme.swift
│       ├── PhotoAsset.swift
│       ├── PhotoContentAnalyzer.swift
│       ├── PhotoPickerBridge.swift
│       ├── PhotoShortcuts.swift
│       ├── PrivacyMosaic.swift
│       ├── SettingsView.swift
│       ├── ShareHandoff.swift
│       └── lingdongzhaopianApp.swift
└── Android/
    └── lingdongzhaopian/
        ├── app/
        │   └── src/main/
        │       ├── AndroidManifest.xml
        │       └── java/cn/locallens/lingdongzhaopian/
        │           ├── AppModels.kt
        │           ├── ArtworkCanvas.kt
        │           ├── ExportManager.kt
        │           ├── GlassComponents.kt
        │           ├── LingdongViewModel.kt
        │           ├── MainActivity.kt
        │           ├── MainScreen.kt
        │           ├── MotionPhotoSupport.kt
        │           ├── PaletteLiquidGlass.kt
        │           ├── PaletteProcessing.kt
        │           ├── PhotoProcessing.kt
        │           └── SettingsAndDialogs.kt
        ├── gradle/
        ├── build.gradle.kts
        └── settings.gradle.kts
```

## 开源许可证

项目源代码采用 [GNU Affero General Public License v3.0](./LICENSE)（`AGPL-3.0-only`）发布。这是一份强互惠开源许可证：复制、修改和再分发代码时必须遵守许可证并提供相应源码；若修改后的程序通过网络向用户提供服务，还需要向这些用户提供对应源码。

AGPL 源代码许可证不授予对应用名称“灵动照片”、项目名称、Logo 或 App Icon 的品牌与商标使用许可；产品页美术和营销截图也不随源代码许可证授权。相关说明见 [TRADEMARKS.md](./TRADEMARKS.md)。许可证是法律文件；如果计划商业分发、闭源集成或向 App Store 提交修改版，请自行取得专业法律意见。

## 贡献

欢迎提交 Issue 和 Pull Request，例如：

- 增加新的画面类别与文案
- 优化 Apple Vision 与 Android ML Kit 的分类权重
- 改进 OKLab 聚类速度与稳定性
- 增加 iPad 横屏布局与更多 Android 大屏适配
- 补充单元测试和 UI 测试
- 提供更多语言本地化

提交代码前，请确保对应平台的 Debug 与 Release 目标均能构建通过，并且不要提交包含个人位置、EXIF 或真实人物信息的测试照片。

## 免责声明

本项目为独立、学习性质的重新实现，与任何同类商业应用及其开发者没有从属、授权或合作关系。请勿提交不属于自己的第三方代码、图标、截图、品牌名称或受版权保护的素材。

如果你喜欢这个项目，点一个 Star 就很好。钱留着买杯咖啡，或者去拍下一张照片。
