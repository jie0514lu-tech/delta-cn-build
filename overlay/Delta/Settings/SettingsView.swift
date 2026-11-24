//
//  SettingsView.swift
//  Delta
//
//  Created by Caroline Moore on 3/31/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

import DeltaCore
import Harmony

private struct SettingsBadge: View
{
    let text: String
    var color: Color = .accentColor

    var body: some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color, in: Capsule())
            .foregroundStyle(.white)
    }
}

struct SettingsView: View
{
    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                PatreonSection()
                ControlsSection()
                EmulationSection()
                OnlineMultiplayerSection()
                DisplaySection()
                LanguageSection()
                ServicesSection()
                MiscellaneousSection()
                CreditsSection()
                SupportSection()
            }
            .safeAreaPadding(.top, 8)
            .navigationTitle("Settings")
            .toolbar {
                if #available(iOS 26, *)
                {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close) {
                            // dismiss() skips presentationControllerDidDismiss, so explicitly sync on close.
                            SyncManager.shared.sync()
                            dismiss()
                        }
                    }
                }
                else
                {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            // dismiss() skips presentationControllerDidDismiss, so explicitly sync on close.
                            SyncManager.shared.sync()
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Controls

private struct ControlsSection: View
{
    @SwiftUI.State
    private var gameControllerManager: ExternalGameControllerManager = .shared

    var body: some View {
        Section("Controls") {
            NavigationLink {
                ControllerSettingsView()
            } label: {
                SettingsRow(label: Text("Controllers"), systemImage: "gamecontroller", color: .purple) {
                    if !gameControllerManager.connectedControllers.isEmpty
                    {
                        Text("\(gameControllerManager.connectedControllers.count) Connected")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            NavigationLink {
                SkinSettingsView()
            } label: {
                SettingsRow(label: Text("Skins"), systemImage: "paintpalette", color: .pink)
            }

            NavigationLink {
                TouchHapticsView()
            } label: {
                SettingsRow(label: Text("Touch & Haptics"), systemImage: "hand.tap", color: .red)
            }
        }
    }
}

// MARK: - Emulation

private struct EmulationSection: View
{
    var body: some View {
        Section("Emulation") {
            NavigationLink {
                AudioSettingsView()
            } label: {
                SettingsRow(label: Text("Audio"), systemImage: "speaker.wave.2", color: .green)
            }

            NavigationLink {
                VideoSettingsView()
            } label: {
                SettingsRow(label: Text("Video"), systemImage: "display", color: .teal)
            }

            NavigationLink {
                CoresListView()
            } label: {
                SettingsRow(label: Text("Cores"), systemImage: "cpu", color: .cyan)
            }
        }
    }
}

// MARK: - Online Multiplayer

private struct OnlineMultiplayerSection: View
{
    var body: some View {
        Section {
            NavigationLink {
                OnlineMultiplayerView()
            } label: {
                SettingsRow(label: Text("Online Multiplayer"), systemImage: "globe", color: .orange)
            }
        }
    }
}

// MARK: - Online Multiplayer Detail

struct OnlineMultiplayerView: View
{
    @SwiftUI.State
    private var preferredWFCServer: String? = Settings.preferredWFCServer

    @SwiftUI.State
    private var isConfirmingReset: Bool = false

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    WFCServersView()
                } label: {
                    LabeledContent {
                        if let serverName = preferredServerName
                        {
                            Text(serverName)
                        }
                        else
                        {
                            Text("Choose")
                                .foregroundColor(Color(uiColor: .deltaPurple))
                        }
                    } label: {
                        Text("WFC Server")
                    }
                }

                if preferredWFCServer != nil
                {
                    Button("Reset Online Settings", role: .destructive) {
                        isConfirmingReset = true
                    }
                    .confirmationDialog("Are you sure you want to reset your online settings?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
                        Button("Reset Online Settings", role: .destructive) {
                            WFCManager.shared.resetWFCConfiguration()
                        }
                    } message: {
                        Text("You may need to re-add any friend codes you’ve previously registered.")
                    }
                }
            } header: {
                Text("Nintendo DS")
            } footer: {
                if preferredWFCServer == nil
                {
                    Text("Choose the 3rd-party Nintendo WFC server Delta should use for online play in Nintendo DS games.")
                }
            }
        }
        .navigationTitle("Online Multiplayer")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: Settings.didChangeNotification)) { notification in
            guard let name = notification.userInfo?[Settings.NotificationUserInfoKey.name] as? Settings.Name,
                  name == .preferredWFCServer else { return }

            preferredWFCServer = Settings.preferredWFCServer
        }
        .onAppear {
            preferredWFCServer = Settings.preferredWFCServer
        }
    }

    private var preferredServerName: String? {
        guard let preferredWFCServer else { return nil }

        if let servers = UserDefaults.standard.wfcServers, let knownServer = servers.first(where: { $0.dns == preferredWFCServer })
        {
            return knownServer.name
        }

        return preferredWFCServer
    }
}

// MARK: - Services

private struct ServicesSection: View
{
    @SwiftUI.State
    private var syncingServiceName: String? = Settings.syncingService?.localizedName
    
    @SwiftUI.State
    private var syncConflictsCount: Int = 0
    
    @SwiftUI.State
    private var isAccountConnected: Bool = SyncManager.shared.coordinator?.account != nil

    @SwiftUI.State
    private var retroAchievementsUsername: String? = Keychain.shared.retroAchievementsUsername

    var body: some View {
        Section {
            NavigationLink {
                SyncingServicesViewController.ViewRepresentable()
                    .ignoresSafeArea()
            } label: {
                SettingsRow(label: Text("Delta Sync"), systemImage: "arrow.triangle.2.circlepath", color: .indigo) {
                    if let name = syncingServiceName {
                        Text(name).foregroundStyle(.secondary)
                    }
                }
            }

            if isAccountConnected
            {
                NavigationLink {
                    SyncStatusViewController.ViewRepresentable()
                        .ignoresSafeArea()
                } label: {
                    SettingsRow(label: Text("Sync Status"), systemImage: "checkmark.icloud", color: .indigo) {
                        if syncConflictsCount > 0
                        {
                            SettingsBadge(text: "\(syncConflictsCount) conflicts", color: .red)
                        }
                        else
                        {
                            SettingsBadge(text: "Up-to-date", color: .green)
                        }
                    }
                }
            }

            NavigationLink {
                AchievementAccount()
            } label: {
                SettingsRow(label: Text("RetroAchievements"), systemImage: "medal", color: .indigo) {
                    if let username = retroAchievementsUsername {
                        Text(username).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Settings.didChangeNotification)) { notification in
            guard let name = notification.userInfo?[Settings.NotificationUserInfoKey.name] as? Settings.Name,
                  name == .syncingService else { return }
            
            syncingServiceName = Settings.syncingService?.localizedName
            isAccountConnected = SyncManager.shared.coordinator?.account != nil
            refreshSyncConflicts()
        }
        .onReceive(NotificationCenter.default.publisher(for: SyncCoordinator.didFinishSyncingNotification).receive(on: DispatchQueue.main)) { _ in
            refreshSyncConflicts()
        }
        .onReceive(NotificationCenter.default.publisher(for: AchievementsManager.didFinishAuthenticatingNotification).receive(on: DispatchQueue.main)) { _ in
            retroAchievementsUsername = Keychain.shared.retroAchievementsUsername
        }
        .onAppear {
            refreshSyncConflicts()
        }
    }

    private func refreshSyncConflicts()
    {
        do {
            let records = try SyncManager.shared.recordController?.fetchConflictedRecords() ?? []
            syncConflictsCount = records.count
        } catch {
            Logger.main.error("Failed to refresh sync conflicts. \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Patreon

private struct PatreonSection: View
{
    var body: some View {
        #if BETA
        return EmptyView()
        #else
        if PurchaseManager.shared.supportsExternalPurchases
        {
            Section {
                NavigationLink {
                    PatreonViewController.ViewRepresentable()
                        .ignoresSafeArea()
                } label: {
                    SettingsRow(
                        label: Text(PurchaseManager.shared.isActivePatron
                            ? "Manage Subscription" : "Become a Patron"),
                        systemImage: "heart",
                        color: .accentColor
                    )
                }
            } footer: {
                Text("Get early access to new features and unlock exclusive app icons.")
            }
        }
        #endif
    }
}

// MARK: - App Icon

private struct DisplaySection: View
{
    var body: some View {
        Section("Display") {
            NavigationLink {
                AltAppIconsViewController.ViewRepresentable()
                    .navigationBarTitleDisplayMode(.large)
                    .ignoresSafeArea()
            } label: {
                SettingsRow(label: Text("App Icon"), systemImage: "square.grid.2x2", color: .blue)
            }
        }
    }
}

// MARK: - Language

private struct LanguageSection: View
{
    @ObservedObject
    private var languageManager: LanguageManager = .shared

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        Section {
            Picker(selection: Binding(get: {
                languageManager.language
            }, set: { newLanguage in
                guard newLanguage != languageManager.language else { return }

                languageManager.select(newLanguage)

                // 关掉设置页，让根视图按新语言重建后立即可见
                dismiss()
            })) {
                ForEach(DeltaLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            } label: {
                Label {
                    Text("Language")
                } icon: {
                    Image(systemName: "globe")
                }
            }
            .pickerStyle(.menu)
        } footer: {
            Text("Switching applies immediately; restart Delta if a game is running.")
        }
    }
}

// MARK: - Experimental, Minor, & Advanced

private struct MiscellaneousSection: View
{
    var body: some View {
        Section {
            NavigationLink {
                MinorSettingsView()
            } label: {
                SettingsRow(label: Text("Lil’ Settings"), systemImage: "slider.horizontal.3", color: .gray)
            }

            NavigationLink {
                AdvancedSettingsView()
            } label: {
                SettingsRow(label: Text("Advanced"), systemImage: "gearshape", color: .gray)
            }
            
            NavigationLink {
                ExperimentalFeaturesView()
            } label: {
                SettingsRow(label: Text("Experimental"), systemImage: "flask", color: .gray) {
                    SettingsBadge(text: "Patrons")
                }
            }
        }
    }
}

// MARK: - Credits

private struct CreditsSection: View
{
    var body: some View {
        Section("Credits") {
            NavigationLink {
                ContributorsView()
            } label: {
                Text("Contributors")
            }

            NavigationLink {
                LicensesViewController.ViewRepresentable()
                    .ignoresSafeArea()
            } label: {
                Text("Software Licenses")
            }
        }
    }
}

// MARK: - Support

private struct SupportSection: View
{
    @Environment(\.openURL)
    var openURL
    
    @SwiftUI.State
    private var showMailError = false

    var body: some View {
        Section {
            Button("Contact Us") {
                // TODO: support attachments
                let email = "support@altstore.io"
                let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
                let subject = "Delta \(version) Feedback"
                let urlString = "mailto:\(email)?subject=\(subject)"
                
                if let url = URL(string: urlString)
                {
                    openURL(url) { success in
                        if !success { showMailError = true }
                    }
                }
            }
            .alert("Cannot Send Mail", isPresented: $showMailError) {}
            
            NavigationLink {
                DeltaLegalDocumentView(document: .privacy)
            } label: {
                Text("Privacy Policy")
            }
            
            NavigationLink {
                DeltaLegalDocumentView(document: .terms)
            } label: {
                Text("Terms of Use")
            }
        } header: {
            Text("Support")
        } footer: {
            RepresentedFooterView()
                .containerRelativeFrame(.horizontal)
        }
    }
}

// MARK: - Footer

private struct RepresentedFooterView: UIViewRepresentable
{
    func makeUIView(context: Context) -> FollowUsFooterView
    {
        let view = FollowUsFooterView(prefersFullColorIcons: false)
        view.stackView.spacing = 20
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.directionalLayoutMargins.top = 8
        view.stackView.directionalLayoutMargins.bottom = 20
        return view
    }

    func updateUIView(_ uiView: FollowUsFooterView, context: Context) {}

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: FollowUsFooterView, context: Context) -> CGSize?
    {
        guard let width = proposal.width ?? uiView.window?.bounds.width else { return nil }

        return uiView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
    }
}

// MARK: - 内置隐私政策 / 使用条款

enum DeltaLegalDocument
{
    case privacy
    case terms
}

struct DeltaLegalDocumentView: View
{
    let document: DeltaLegalDocument

    private var title: String {
        switch self.document
        {
        case .privacy: return NSLocalizedString("Privacy Policy", comment: "")
        case .terms: return NSLocalizedString("Terms of Use", comment: "")
        }
    }

    private var body_: String {
'        let isChinese: Bool
        switch LanguageManager.shared.language
        {
        case .chinese: isChinese = true
        case .english: isChinese = false
        case .system: isChinese = Locale.preferredLanguages.first?.hasPrefix("zh") ?? false
        }'
        switch self.document
        {
        case .privacy: return isChinese ? DeltaLegalText.privacyZH : DeltaLegalText.privacyEN
        case .terms: return isChinese ? DeltaLegalText.termsZH : DeltaLegalText.termsEN
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(self.body_)
                    .font(.callout)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
        }
        .navigationTitle(self.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum DeltaLegalText
{
    static let privacyEN = """
PRIVACY POLICY — Last updated March 06, 2024

This is the Privacy Policy for the website hosted at https://altstore.io (our site), our products and services, and for other AltStore activities at which you may provide your personal data. The site is operated by or on behalf of AltStore, LLC (we, us, our). We are committed to protecting and respecting your privacy.

This policy sets out: information we collect; how we use your information; lawful bases; who we share your information with; where we store your information; how we respond to DNT signals; how we protect your information; how long we keep your information; EU Citizen Rights; a note to users outside the United States; and changes to this policy.

Please read the following carefully to understand our views and practices regarding your personal data. By engaging in our site and services, you acknowledge you have read and understood this privacy policy. Where applicable privacy law includes the GDPR, the data controller is: AltStore, LLC, 4130 Bowser Ave., Dallas, TX 75219, United States.

Our site may contain links to external sites. We are not responsible for the privacy policies or the content of such sites.

INFORMATION WE COLLECT
We may collect and process the following personal data from you: information you give us by filling in forms on our site or by corresponding with us by phone, e-mail, or otherwise. If you use our products or services as a developer, we may receive and process End User Technical Information (such as device type and operating system), End User Transaction Information, and Optional End User Information, collectively End User Information.

HOW WE USE YOUR INFORMATION
We use this information in our legitimate interests (where not overridden by your rights): to administer our site and for internal operations including troubleshooting, data analysis, testing, research, statistical and survey purposes; and to keep our site safe and secure. We may combine information you give us with information we collect about you and use it for the purposes above.

LAWFUL BASES
We only collect and process personal data where we have lawful bases: consent, contract (to operate the site or deliver products/services you requested), and legitimate interests (only where not overridden by the impact on you).

WHO WE SHARE YOUR INFORMATION WITH
We may share your information with selected third parties including payment processing providers such as Stripe (your payment card details are not shared with us by the provider). We disclose personal information to third parties: in the event we sell or buy any business or assets; if AltStore or substantially all of its assets are acquired by a third party; and where we are under a duty to disclose in order to comply with a legal obligation, to enforce our terms, or to protect the rights, property, or safety of AltStore, our customers, or others.

WHERE WE STORE YOUR INFORMATION
The data we collect from you is stored securely on Amazon Web Services (AWS) in Frankfurt, Germany.

HOW WE RESPOND TO DNT SIGNALS
We do not alter our practices when we receive a Do Not Track signal, because we do not track visitors to provide targeted advertising.

PUBLIC FORUMS
Any information disclosed in chat rooms, message boards, news groups or other public forums becomes public information; please exercise caution and avoid posting personal information.

CHILD SAFETY
The site is intended for use only by persons at least 16 years of age. If you are under 16, you confirm you have permission from your parent or guardian before using this site or sending us personal information.

PAYMENT PROCESSING
Payments on the site are made through our payment gateway provider, which operates a secure server and encrypts your card information. Information you supply is subject to that operator's own privacy policy and terms.

HOW LONG WE KEEP YOUR INFORMATION
We retain personal data while you have an interest in our products and services and an account with us, and for some time after that to identify issues and resolve legal proceedings. We may retain aggregate information longer for research and improvement; you cannot be identified from it.

EU CITIZEN RIGHTS UNDER GDPR
Under certain circumstances you have the right: to be provided with a copy of your personal data held by us; to request rectification or erasure of your personal data; to request restriction of processing; to object to further processing, including marketing; to request portability of your data to a third party; and to withdraw consent at any time where processing is based on consent.

NOTE TO USERS OUTSIDE THE UNITED STATES
AltStore is based in the United States. Your personal data may be stored and processed in any country where we have facilities or engage service providers, and by using the Services you consent to the transfer of information to countries outside your country of residence, including the United States, which may have different data protection rules.

CHANGES TO THIS POLICY
Any changes will be posted on this page and, for substantive changes, notified by email.

CONTACT US
Compliance Officer, AltStore, LLC, 4130 Bowser Ave., Dallas, TX 75219, United States.
"""

    static let privacyZH = """
隐私政策 —— 最后更新：2024 年 3 月 6 日

本隐私政策适用于 https://altstore.io 网站（下称"本网站"）、我们的产品与服务，以及你在与 AltStore 相关的其他活动中向我们提供的个人数据。本网站由 AltStore, LLC（下称"我们"）运营。我们承诺保护并尊重你的隐私。

本政策说明：我们收集哪些信息、如何使用、合法性基础、与谁共享、数据存储地点、如何响应 DNT 信号、如何保护信息、保留期限、欧盟公民权利、对美国以外用户的说明，以及本政策的变更。

请仔细阅读以了解我们对个人数据的看法与做法。使用本网站与服务即表示你已阅读并理解本隐私政策。在适用法律包含《通用数据保护条例》（GDPR）的范围内，数据控制者为：AltStore, LLC, 4130 Bowser Ave., Dallas, TX 75219, United States。

本网站可能包含外部链接。我们不对这些网站的隐私政策或内容负责。

我们收集的信息
我们可能收集并处理你提供的以下个人数据：你在本网站表单中填写的信息，或通过电话、电子邮件等方式与我们沟通时提供的信息。若你作为开发者使用我们的产品或服务，我们可能接收并处理"终端用户技术信息"（如设备类型、操作系统）、"终端用户交易信息"与"可选终端用户信息"，合称"终端用户信息"。

我们如何使用你的信息
在未被你的权利所覆盖的前提下，我们基于正当利益使用这些信息：管理本网站及内部运营（包括故障排查、数据分析、测试、研究、统计与调查），以及保障网站安全。

合法性基础
我们仅在具备合法性基础时收集与处理个人数据：同意、合同履行（运营网站或提供你请求的产品/服务），以及正当利益（仅在不会不当影响你的前提下）。

我们与谁共享信息
我们可能与特定第三方共享信息，包括 Stripe 等支付处理服务商（服务商不会将你的支付卡信息提供给我们）。在以下情形我们也会披露个人信息：出售或购买业务/资产时；AltStore 或其绝大部分资产被第三方收购时；为遵守法律义务、执行我们的条款，或保护 AltStore、客户及他人的权利、财产或安全时。

信息存储地点
我们从你处收集的数据安全存储于位于德国法兰克福的 Amazon Web Services（AWS）。

如何响应 DNT 信号
收到"Do Not Track"信号时我们不会改变做法，因为我们不会为定向广告而跟踪访客。

公开论坛
在聊天室、留言板、新闻组或其他公开论坛披露的任何信息都会成为公开信息，请谨慎使用并避免发布个人信息。

未成年人保护
本网站仅面向年满 16 周岁的人士。若你未满 16 周岁，请确认已获得父母或监护人的许可后再使用本网站或向我们发送个人信息。

支付处理
本网站上的支付通过我们的支付网关服务商完成，该服务商使用安全服务器并对你的卡片信息加密。你提供的信息不受我们控制，适用该服务商自身的隐私政策与条款。

信息保留期限
在你对我们的产品与服务有兴趣并持有账户期间，我们会保留个人数据；此后一段时间内也会保留，以识别问题并处理法律程序。我们可能更长时间保留聚合信息用于研究与改进，此类信息无法识别到你个人。

GDPR 下的欧盟公民权利
在特定情形下，你有权：获得我们所持有的你的个人数据副本；要求更正或删除你的个人数据；要求限制处理（例如在我们核实或调查期间）；反对进一步处理（包括营销）；要求将你提供的个人数据转移给第三方；以及在处理基于同意时随时撤回同意。

对美国以外用户的说明
AltStore 位于美国。你的个人数据可能在我们设有设施或聘有服务商的任何国家存储和处理；使用本服务即表示你同意将信息传输至你居住国以外的国家（包括美国），这些国家的数据保护规则可能与你所在国不同。

本政策的变更
任何变更都会发布在本页面；重大变更将通过电子邮件通知你。

联系我们
合规负责人：AltStore, LLC, 4130 Bowser Ave., Dallas, TX 75219, United States。
"""

    static let termsEN = """
TERMS OF USE — Purchase Terms, last updated December 3, 2024

PATREON SUBSCRIPTION TERMS
Subscriptions made through our Patreon campaign are subject to Patreon's Terms of Use.

IN-APP PURCHASE TERMS
Your subscription grants you access to benefits from all tiers (Early Adopter, Discord, and Friend Zone) listed on our Patreon campaign, and is subject to Apple's Terms of Use. Your subscription will be charged to your iTunes Account once you confirm your purchase. Your iTunes account will be charged again when your subscription automatically renews at the end of your current subscription period unless auto-renew is turned off at least 24 hours prior to the end of the current period. You can manage or turn off auto-renew in your Apple ID Account Settings any time after purchase.

Apple's standard End User License Agreement (EULA) applies to this app.
"""

    static let termsZH = """
使用条款 —— 购买条款，最后更新：2024 年 12 月 3 日

Patreon 订阅条款
通过我们的 Patreon 活动进行的订阅，适用 Patreon 的使用条款。

应用内购买条款
你的订阅可解锁我们在 Patreon 活动页列出的全部等级（Early Adopter、Discord、Friend Zone）的权益，并适用 Apple 的使用条款。你确认购买后，订阅费用将计入你的 iTunes 账户。除非你在当前订阅期结束至少 24 小时前关闭自动续订，否则订阅将在当期结束时自动续订并再次扣费。购买后你可随时在 Apple ID 账户设置中管理或关闭自动续订。

本应用适用 Apple 的标准最终用户许可协议（EULA）。
"""
}

#Preview {
    SettingsView()
}
