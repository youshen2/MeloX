# MeloX iPad 布局与验证

iPad 的常规宽度窗口使用原生侧栏和底部播放条，内容尺寸根据当前窗口计算。

- 搜索位于侧栏顶部，账号入口固定在底部；音乐库分类可直接访问。听歌识曲和登录后的私信位于主页面右上角。
- 播放条包含歌曲信息、播放控制、歌词和队列入口；窗口足够宽时显示进度条。
- 全屏播放器按窗口高度限制封面尺寸，歌词、队列和原生触控按钮适配旋转及较窄窗口。歌词和队列快捷入口直接传递初始页面。
- 歌单、榜单和专辑采用横向封面与信息头，下方显示整宽歌曲表；宽窗口独立展示歌手和时长。
- 发现页的推荐竖卡按可用宽度排满完整卡片，与下方歌单网格共享左右边缘；长短标题的网格封面按顶边排列。
- 首页、音乐库网格和分享等工具栏符号使用统一的尺寸规则。

## 验证记录

设备 Release 编译、布局边界检查以及 6 项 UI 检查已经通过。UI 环境为 iPad Pro 13-inch (M4)、iPadOS 27.0 模拟器，失败和运行时警告均为 0。对应测试源提交为 `620d10ab0be00399d014c1b45aab0a11dc540288`。

UI 检查覆盖侧栏分类、账号固定底栏与列表滚动、歌词/队列入口、横竖屏、较大字体、歌曲首屏可见性、按钮中心，以及推荐行和网格的边缘对齐。测试数据只在 `DEBUG && targetEnvironment(simulator)` 下启用。模拟器验证没有覆盖真机登录、联网播放或签名安装。

## 本地运行

按照项目现有要求使用 Xcode 27.1 或更新版本，最低运行系统仍为 iOS / iPadOS 26.0。

布局边界检查：

```sh
mkdir -p build
xcrun swiftc MeloX/Features/Player/NowPlaying/Tablet/NowPlayingTabletLayout.swift MeloX/Features/MusicCollection/MusicCollectionDetailMetrics.swift MeloX/Features/Explore/ExploreFeaturedMetrics.swift .github/scripts/ValidateTabletLayout.swift -o build/validate-tablet-layout
build/validate-tablet-layout
```

在临时检出中执行 UI 检查，因为准备脚本会临时添加 UI 测试目标和修改 scheme：

```sh
python3 .github/scripts/prepare_ipad_ui_tests.py
xcodebuild test -project MeloX.xcodeproj -scheme MeloX -configuration Debug -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4),OS=27.0' -derivedDataPath build/DerivedData-UI -resultBundlePath build/ipad-ui.xcresult -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' DEVELOPMENT_TEAM=''
xcrun xcresulttool export attachments --path build/ipad-ui.xcresult --output-path build/screenshots
xcrun xcresulttool get test-results summary --path build/ipad-ui.xcresult
```

设备构建使用项目的 `build_ios_unsigned.sh`；以上命令可在临时检出中重复执行布局和 UI 检查。

## 截图

以下图片来自已通过检查的模拟器，使用示例曲目。

| 侧栏与播放条 | 发现页 |
| --- | --- |
| ![iPad 侧栏与播放条](docs/screenshots/ipad/home.png) | ![对齐的推荐卡片与网格](docs/screenshots/ipad/discover.png) |

| 歌单信息与歌曲表 | 横屏歌词 |
| --- | --- |
| ![iPad 歌单信息与歌曲表](docs/screenshots/ipad/collection.png) | ![iPad 横屏歌词](docs/screenshots/ipad/player.png) |
