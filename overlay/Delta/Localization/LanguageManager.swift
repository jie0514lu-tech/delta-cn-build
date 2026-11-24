//
//  LanguageManager.swift
//  Delta
//
//  简体中文 / English 运行时切换
//
//  说明：
//  * Swift / SwiftUI 侧的文案由 Bundle 类级 swizzle 即时重定向；
//  * 但 storyboard / xib 的本地化由 iOS 在**进程启动时**按 AppleLanguages 解析并缓存，
//    运行中无法改变（UIKit 不走 NSBundle 的消息派发），因此写入 AppleLanguages 后
//    需要重启进程才能让 UIKit 界面也切到新语言。
//

import Foundation
import ObjectiveC.runtime
import Combine
import UIKit

// MARK: - 语言

enum DeltaLanguage: String, CaseIterable, Identifiable
{
    case system = "system"
    case english = "en"
    case chinese = "zh-Hans"

    var id: String { self.rawValue }

    /// 用于查找 .lproj 的语言代码；nil 表示交回系统决定。
    var bundleCode: String? {
        switch self
        {
        case .system: return nil
        case .english: return "en"
        case .chinese: return "zh-Hans"
        }
    }

    var displayName: String {
        switch self
        {
        case .system: return NSLocalizedString("Follow System", comment: "")
        case .english: return NSLocalizedString("English", comment: "")
        case .chinese: return NSLocalizedString("Simplified Chinese", comment: "")
        }
    }
}

// MARK: - Bundle 语言重定向（类级 swizzle）

extension Bundle
{
    static func delta_installLanguageSwizzle()
    {
        let cls: AnyClass = Bundle.self

        func swap(_ original: Selector, _ replacement: Selector)
        {
            guard
                let a = class_getInstanceMethod(cls, original),
                let b = class_getInstanceMethod(cls, replacement)
            else { return }
            method_exchangeImplementations(a, b)
        }

        swap(#selector(Bundle.localizedString(forKey:value:table:)),
             #selector(Bundle.delta_localizedString(forKey:value:table:)))
        swap(#selector(Bundle.url(forResource:withExtension:)),
             #selector(Bundle.delta_url(forResource:withExtension:)))
        swap(#selector(Bundle.path(forResource:ofType:)),
             #selector(Bundle.delta_path(forResource:ofType:)))
    }

    private var delta_languageOverrideBundle: Bundle? {
        guard self.bundlePath == Bundle.main.bundlePath else { return nil }
        return LanguageManager.shared.activeBundle
    }

    @objc func delta_localizedString(forKey key: String, value: String?, table tableName: String?) -> String
    {
        if let override = self.delta_languageOverrideBundle
        {
            return override.localizedString(forKey: key, value: value, table: tableName)
        }
        return self.delta_localizedString(forKey: key, value: value, table: tableName)
    }

    @objc func delta_url(forResource name: String?, withExtension ext: String?) -> URL?
    {
        if let override = self.delta_languageOverrideBundle, let url = override.url(forResource: name, withExtension: ext)
        {
            return url
        }
        return self.delta_url(forResource: name, withExtension: ext)
    }

    @objc func delta_path(forResource name: String?, ofType ext: String?) -> String?
    {
        if let override = self.delta_languageOverrideBundle, let path = override.path(forResource: name, ofType: ext)
        {
            return path
        }
        return self.delta_path(forResource: name, ofType: ext)
    }
}

// MARK: - 语言管理器

final class LanguageManager: ObservableObject
{
    static let shared = LanguageManager()

    static let didChangeNotification = Notification.Name("DeltaLanguageDidChangeNotification")

    private static let defaultsKey = "DeltaPreferredLanguage"

    @Published private(set) var language: DeltaLanguage

    /// 当前选中的语言包；nil 表示跟随系统
    private(set) var activeBundle: Bundle?

    private init()
    {
        let stored = UserDefaults.standard.string(forKey: LanguageManager.defaultsKey)
        self.language = stored.flatMap(DeltaLanguage.init(rawValue:)) ?? .system
    }

    /// 用户切换语言
    func select(_ language: DeltaLanguage)
    {
        guard language != self.language else { return }

        UserDefaults.standard.set(language.rawValue, forKey: LanguageManager.defaultsKey)
        self.language = language

        LanguageManager.writeAppleLanguages(language)
        self.applyCurrentLanguage()

        NotificationCenter.default.post(name: LanguageManager.didChangeNotification, object: self, userInfo: nil)
    }

    /// 启动时应用已保存的选择（AppDelegate 调用）
    func applyStoredLanguage()
    {
        Bundle.delta_installLanguageSwizzle()
        self.applyCurrentLanguage()
        LanguageManager.writeAppleLanguages(self.language)
    }

    private func applyCurrentLanguage()
    {
        Bundle.delta_installLanguageSwizzle()

        guard
            let code = self.language.bundleCode,
            let path = Bundle.main.path(forResource: code, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else
        {
            self.activeBundle = nil
            return
        }

        self.activeBundle = bundle
    }

    /// 写入 AppleLanguages：iOS 下次启动时会按这个顺序解析 .lproj（含 storyboard）
    private static func writeAppleLanguages(_ language: DeltaLanguage)
    {
        let defaults = UserDefaults.standard

        if let code = language.bundleCode
        {
            var languages = [code]
            if code != "en" { languages.append("en") }
            defaults.set(languages, forKey: "AppleLanguages")
        }
        else
        {
            defaults.removeObject(forKey: "AppleLanguages")
        }
        defaults.synchronize()
    }
}

// MARK: - 切换后的界面刷新 / 重启提示

extension LanguageManager
{
    /// 切换语言后：SwiftUI 侧即时刷新；storyboard（UIKit）侧需重启进程才生效，因此总是提示重启。
    static func refreshAfterLanguageChange()
    {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            LanguageManager.reloadInterface()
            LanguageManager.presentRestartAlert()
        }
    }

    /// 重建根视图：让已经创建好的 SwiftUI / Swift 侧界面立即用新语言重新渲染。
    @discardableResult
    static func reloadInterface() -> Bool
    {
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard
            let windowScene = windowScenes.first(where: { $0.activationState == .foregroundActive }) ?? windowScenes.first,
            let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first
        else { return false }

        // 正在模拟游戏中：重建会打断会话，交给用户决定何时重启
        if let sceneDelegate = windowScene.delegate as? SceneDelegate, sceneDelegate.game != nil
        {
            return false
        }

        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        guard let rootViewController = storyboard.instantiateInitialViewController() else { return false }

        UIView.transition(with: window, duration: 0.3, options: [.transitionCrossDissolve]) {
            window.rootViewController = rootViewController
        }

        return true
    }

    /// 提示重启（storyboard 界面的本地化在进程启动时解析，无法运行中切换）
    static func presentRestartAlert()
    {
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let windowScene = windowScenes.first(where: { $0.activationState == .foregroundActive }) ?? windowScenes.first,
              var topViewController = (windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first)?.rootViewController
        else { return }

        while let presented = topViewController.presentedViewController
        {
            topViewController = presented
        }

        let alertController = UIAlertController(title: NSLocalizedString("Language Changed", comment: ""),
                                                message: NSLocalizedString("Please restart Delta to apply the new language.", comment: ""),
                                                preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Restart now", comment: ""), style: .default) { _ in
            exit(0)
        })
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Later", comment: ""), style: .cancel))
        topViewController.present(alertController, animated: true)
    }
}
