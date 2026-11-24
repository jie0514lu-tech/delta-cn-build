# Delta 中文版构建配方（Delta · 简体中文本地化）

> 本项目是 [**@rileytestut**](https://github.com/rileytestut) 的 [**Delta**](https://github.com/rileytestut/Delta) 模拟器的**非官方简体中文本地化构建配方**。
> 原始项目版权归 Riley Testut 与贡献者所有，采用 **AGPL-3.0** 许可；本仓库同样以 AGPL-3.0 发布，仅包含中文本地化资源与构建所需的最小改动，**不含上游源码**。

## 这是什么

- 一个**很小的配方仓库**，CI 会自己克隆上游 Delta 到固定提交 `bc3d77b1d`，打上中文本地化补丁 + 资源覆盖层，然后在 macOS runner 上编译出 `Delta-CN-unsigned.ipa`。
- 由 **AI 生成/编译**：本地化文案、代码改动和构建流水线均由 AI 编写，作者只做了需求确认与真机验收。
- **只做了中文本地化 + 一个语言切换入口**，没有改动任何模拟器逻辑、核心、存档格式或网络行为。

## 本地化做了什么

| 内容 | 说明 |
|---|---|
| `static strings` | `Localizable.strings` 681 条（en / zh-Hans 各一份），覆盖上游全部 `NSLocalizedString` / SwiftUI 字面量 key |
| storyboard | 5 个 `*.strings`（Main / Settings / PauseMenu / GamesDatabase / PausePresentationControllerContentView），按对象 ID 映射，共 126 条 |
| 术语 | Save State=即时存档、Cheat=金手指、Controller Skin=手柄皮肤、Fast Forward=快进、App Icon=应用图标 等统一 |

## 代码改动（仅 4 处 + 1 个新文件）

| 文件 | 改动 |
|---|---|
| `Delta/Localization/LanguageManager.swift` | **新增**。`DeltaLanguage`（跟随系统 / English / 简体中文）、`LanguageManager`（UserDefaults 记 `DeltaPreferredLanguage`）、`DeltaLanguageBundle`（`object_setClass` 替换 `Bundle.main`，把本地化查表重定向到指定 `.lproj`），以及"切换后重建根视图"的免重启刷新 |
| `Delta/AppDelegate.swift` | 启动时 `LanguageManager.shared.applyStoredLanguage()`（1 行） |
| `Delta/Settings/SettingsView.swift` | 设置页新增「语言 / Language」Picker |
| `Delta/Supporting Files/Info.plist` | `CFBundleLocalizations = [en, zh-Hans]` |
| `Delta.xcodeproj/project.pbxproj` | 登记上面两个新资源/源文件 |

其余全部上游代码一字未改。

## 语言切换行为

- 设置 → 语言 / Language → 跟随系统 / English / 简体中文
- 切换后**立即生效**（自动重建根视图，不需要手动重启）；如果当时正在模拟器中跑游戏，会提示重启后再生效，避免打断会话
- 跟随系统：系统是简体中文 → 中文；繁体环境通常回退简体；其他语言 → 英文（回退到 `CFBundleDevelopmentRegion`）

## 构建期兼容处理（不影响运行时逻辑）

CI 里的三个 shim 是为了让上游代码能在 GitHub 的 runner 上编译出来，全部可在日志中核对：

1. **Xcode 选择**：取 runner 上最新的 Xcode 26.x（iOS 26.5 SDK）。
2. **CoreData 映射模型版本标记**：上游 `Delta11ToDelta13` / `Delta12ToDelta13` 映射模型由更新版 Xcode 生成（`Persistence-1629`），runner 的 `momc` 只支持到 `1526`，会直接报错；shim 只把这两个 XML 里的编译期版本号降到 1526，**不改动任何实体/属性映射**。
3. **App 图标**：Xcode 26.x 的 `actool` 在编译 Icon Composer `.icon` 与 `Icons.xcassets` 时会崩（[expo#46121](https://github.com/expo/expo/issues/46121)），因此 CI 用 `Icons.xcassets/Raw/AppIcon.imageset` 里的 1024×1024 PNG 生成经典 `AppIcon.appiconset`，并把 `.icon` / `Icons.xcassets` 移出编译。
   - 影响：主图标正常；**Patreon 的备用图标（Icon Pack）不可用**；Liquid Glass 分层图标退化为普通图标。

## 产物

`Delta-CN-unsigned.ipa`：未签名，需要用你自己的证书重签后安装（Sideloadly / AltStore / 爱思助手 / ESign 选"重签"，或 `codesign -f -s "你的证书" Payload/Delta.app`）。

## 自行构建

- 仓库 Actions 页手动 Run `Build Delta CN IPA`，或 push 到 `main`；
- 产物在对应 run 的 Artifacts：`Delta-CN-unsigned-ipa`（含 `sha256.txt`、`build.log`）；
- 本地构建（有 Mac）：把 `patch/` 与 `overlay/` 套到 `bc3d77b1d` 的源码上，`pod install` 后 `xcodebuild` 即可，具体参见 workflow 里的步骤。

## 免责与许可

- 非官方构建，与 Riley Testut / AltStore 无关；请支持上游与 Patreon 版本。
- 上游 Delta 使用 **AGPL-3.0**，本仓库的改动同样是 AGPL-3.0，修改与再分发请遵守该许可证（尤其需要提供对应源码）。
- 仅供个人学习与自用；因使用本构建产生的任何问题由使用者自行承担。

## 致谢

- [@rileytestut](https://github.com/rileytestut) —— Delta 原作者
- [@carolinemoore](https://github.com/carolinemoore) —— Delta 界面与设计
- Delta 全部贡献者与各模拟器核心作者（melonDS / Snes9x / Gambatte / Nestopia / mupen64plus / Genesis Plus GX 等）
