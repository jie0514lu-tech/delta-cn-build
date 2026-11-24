//
//  LanguageManager.swift
//  Delta
//
//  中英双语支持：运行时切换语言（跟随系统 / English / 简体中文）
//
//  工作方式：
//  1. 应用启动时把 Bundle.main 的 isa 换成 DeltaLanguageBundle，
//     让所有 NSLocalizedString / SwiftUI LocalizedStringKey 的查表走指定 .lproj。
//  2. 用户在设置里选择语言后，立即重新绑定语言包，并提示重启以让已渲染的界面生效。
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

    /// 用于查找对应 .lproj 的语言代码；nil 表示交回系统决定。
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

// MARK: - Bundle 语言重定向

private var deltaLanguageBundleKey: UInt8 = 0

final class DeltaLanguageBundle: Bundle
{
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String
    {
        guard let languageBundle = objc_getAssociatedObject(self, &deltaLanguageBundleKey) as? Bundle else {
            // 没有指定语言（跟随系统）→ 走系统默认查找
            return super.localizedString(forKey: key, value: value, table: tableName)
        }

        return languageBundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

// MARK: - 语言管理器

final class LanguageManager: ObservableObject
{
    static let shared = LanguageManager()

    static let didChangeNotification = Notification.Name("DeltaLanguageDidChangeNotification")

    private static let defaultsKey = "DeltaPreferredLanguage"

    @Published private(set) var language: DeltaLanguage

    private init()
    {
        let stored = UserDefaults.standard.string(forKey: LanguageManager.defaultsKey)
        self.language = stored.flatMap(DeltaLanguage.init(rawValue:)) ?? .system

        self.bindLanguageBundle(self.language.bundleCode)
    }

    /// 用户切换语言：立刻生效到后续所有本地化查找，并广播通知。
    func select(_ language: DeltaLanguage)
    {
        guard language != self.language else { return }

        UserDefaults.standard.set(language.rawValue, forKey: LanguageManager.defaultsKey)
        self.language = language

        self.bindLanguageBundle(language.bundleCode)

        NotificationCenter.default.post(name: LanguageManager.didChangeNotification, object: self, userInfo: nil)

        LanguageManager.reloadInterfaceAfterDelay()
    }

    /// 启动时应用已保存的选择（AppDelegate 调用）。
    func applyStoredLanguage()
    {
        self.bindLanguageBundle(self.language.bundleCode)
    }

    private func bindLanguageBundle(_ code: String?)
    {
        object_setClass(Bundle.main, DeltaLanguageBundle.self)

        guard
            let code = code,
            let path = Bundle.main.path(forResource: code, ofType: "lproj"),
            let languageBundle = Bundle(path: path)
        else
        {
            objc_setAssociatedObject(Bundle.main, &deltaLanguageBundleKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return
        }

        objc_setAssociatedObject(Bundle.main, &deltaLanguageBundleKey, languageBundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

// MARK: - 免重启刷新界面

extension LanguageManager
{
    /// 切换语言后稍等片场再刷新，让设置页先完成消失动画。
    static func reloadInterfaceAfterDelay()
    {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if !LanguageManager.reloadInterface()
            {
                LanguageManager.presentRestartNotice()
            }
        }
    }

    /// 重建根视图：所有界面按新语言重新创建 / 重新查表，用户不需要手动重启。
    /// 返回 false 表示当前状况不适合重建（例如游戏正在运行），此时退化为提示重启。
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

    /// 无法即时刷新时的兜底提示。
    static func presentRestartNotice()
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
        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .cancel))
        topViewController.present(alertController, animated: true)
    }
}
