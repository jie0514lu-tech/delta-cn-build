# Delta 简体中文版（构建配方）

> 基于 [**@rileytestut**](https://github.com/rileytestut) 的 [**Delta**](https://github.com/rileytestut/Delta) 模拟器（上游提交 `bc3d77b1d`，版本 2.0.4）的**非官方简体中文构建**。
> 上游与贡献者版权归原作者所有，采用 **AGPL-3.0** 许可；本仓库同样以 AGPL-3.0 发布，**不包含上游源码**，只包含本地化资源与最小代码改动。
> 本构建由 **AI 编写与编译**，人工只做需求确认与真机验收。

## 下载

- **IPA**：[Releases → v2.0.4-cn](https://github.com/jie0514lu-tech/delta-cn-build/releases/tag/v2.0.4-cn) 里的 `Delta-CN-unsigned.ipa`（未签名，需自行重签）
- 源码快照：同一 Release 页面的 `Source code (zip / tar.gz)`
- 安装：Sideloadly / AltStore / 爱思助手 / ESign 选「重签」，或 `codesign -f -s "你的证书" Payload/Delta.app`

## 语言切换（重要）

设置 → **语言 / Language** → 跟随系统 / English / 简体中文

**切换后需要重启一次 Delta 才完全生效**，这是 iOS 机制决定的，不是实现偷懒：

- Swift / SwiftUI 文案：通过 Bundle 类级 swizzle 即时重定向，立刻生效
- storyboard / xib 文案：iOS 在**进程启动时**按 `AppleLanguages` 解析 `.lproj` 并缓存，UIKit 不走 `NSBundle` 的消息派发，运行中无法改变
- 因此切换语言时会写入 `AppleLanguages` 并弹出提示，点「立即重启」即完成切换

## 本地化范围

| 内容 | 数量 |
|---|---|
| `Localizable.strings`（en / zh-Hans 各一份） | 850 条 |
| storyboard / xib 本地化表（按本版本对象 ID 生成） | 6 个文件 139 条 |
| `WhatsNew.plist` / `AltIcons.plist` / `Contributors.plist` 中文副本 | 全量 |
| 隐私政策 / 使用条款 | 改为应用内页面，随 App 内语言显示中文译本或官方英文原文 |

术语统一：即时存档、金手指、手柄皮肤、快进、应用图标、核心、同步、赞助者。品牌名处理：`Delta Sync` → **Delta 同步**、`RetroAchievements` → **RetroAchievements 成就**（如需保留纯英文，改 `tools/zh_extra_round3.json` 即可）。

## 代码改动

| 文件 | 改动 |
|---|---|
| `Delta/Localization/LanguageManager.swift`（新增） | `DeltaLanguage` + `LanguageManager`（UserDefaults `DeltaPreferredLanguage` + 写入 `AppleLanguages`）+ Bundle 类级 swizzle（localizedString / url(forResource:) / path(forResource:)） |
| `Delta/AppDelegate.swift` | 启动时应用已保存语言（1 行） |
| `Delta/Settings/SettingsView.swift` | 增加语言选择器；应用图标页入口；隐私政策 / 使用条款改为内置页面 |
| `Delta/Settings/App Icon/AltAppIconsViewController.swift` | 列表 → **卡片网格**：图标预览 + 名称 + 作者，选中打勾；非赞助者图标**置灰 + 感叹号 + 点击弹提示**（与原版一致不可用） |
| `Delta/Supporting Files/Info.plist` | `CFBundleLocalizations = [en, zh-Hans]` |
| `project.pbxproj` | 登记新文件 |

## 构建期 shim（不影响运行时逻辑，日志可核对）

1. 选择 runner 上最新的 Xcode 26.x（iOS 26.5 SDK）
2. CoreData 映射模型的编译期版本标记从 `1629` 降到 `1526`（runner 的 `momc` 上限），不改数据结构
3. `AppIcon.icon`（Icon Composer）移出编译，改用 `Icons.xcassets` 内的 1024 PNG 生成经典 `AppIcon.appiconset`（规避 Xcode 26 的 actool 崩溃：[expo#46121](https://github.com/expo/expo/issues/46121)）
4. `Icons.xcassets` 先单独试编译，成功则保留（备用图标可用）

## 体积说明

IPA 约 190 MiB：备用图标包（Classic / Modern / Patrons / Patron Button Pack 共 40+ 图标，含深/浅色变体）全部编译进 `Assets.car`，换来图标页的真实预览与切换能力。如需小体积版本，可把 `Icons.xcassets` 移出编译（图标页退化为无预览、不可切换）。

## 已知限制

- 个别第三方核心（DeltaCore / 各 `*DeltaCore.bundle`）自带的内部提示仍为英文，属框架资源
- 少量含字符串插值的动态文案（如 `"\(game.name) Settings"`）无法静态翻译
- 繁体中文环境回退到简体；如需 `zh-Hant` 资源可另加

## 许可与致谢

- 上游 Delta：**AGPL-3.0**；本仓库改动同样遵循该许可，再分发需提供对应源码
- 致谢 [@rileytestut](https://github.com/rileytestut)（Delta 作者）、[@carolinemoore](https://github.com/carolinemoore)（界面设计）及全部上游贡献者与各模拟器核心作者
- 非官方构建，与 Riley Testut / AltStore 无关联；请支持上游与 Patreon 版本
