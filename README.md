# Delta 中英双语构建配方（云端 macOS 编译）

这个仓库不含 Delta 全部源码（70MB+），只放"配方"：CI 自己克隆官方仓库到指定 commit，打补丁、铺资源，然后编译出带**应用内语言切换器**的 IPA。

## 内容

| 路径 | 作用 |
|---|---|
| `PATCHED_COMMIT` | 官方 `rileytestut/Delta` 的目标 commit（补丁基于它生成） |
| `patch/delta-cn.patch` | 4 个代码文件的改动：`AppDelegate.swift`、`Settings/SettingsView.swift`、`Supporting Files/Info.plist`、`project.pbxproj` |
| `overlay/Delta/Localization/LanguageManager.swift` | 新增：`DeltaLanguage` + `LanguageManager` + `DeltaLanguageBundle`（运行时把 `Bundle.main` 的本地化查表重定向到指定 `.lproj`） |
| `overlay/Delta/Resources/zh-Hans.lproj/*.strings` | 681 条中文本地化（`Localizable.strings` + 5 个 storyboard 表） |
| `overlay/Delta/Resources/en.lproj/Localizable.strings` | 英文对照表，切回英文不回落 |
| `.github/workflows/build.yml` | macos-15 构建流水线，产物 `Delta-CN-unsigned-ipa` artifact |

## 产物

`Delta-CN-unsigned.ipa`（未签名）+ `sha256.txt` + `build.log`。

装之前用你自己的证书重签（Sideloadly / AltStore / 爱思助手 / ESign 选"重签"，或 `codesign -f -s "你的证书" Payload/Delta.app`）。

## 装好之后怎么切语言

设置 → 语言 / Language → 跟随系统 / English / 简体中文，切换后重启 Delta 生效（App 内弹窗会提示）。
