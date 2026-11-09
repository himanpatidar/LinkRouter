import AppKit
import SwiftUI
import LinkRouterCore
import ServiceManagement

enum SettingsPage: String, CaseIterable, Identifiable {
    case overview = "Overview", general = "General", destinations = "Destinations", rules = "Rules", privacy = "Privacy"
    var id: String { rawValue }
    var symbol: String { switch self { case .overview: return "square.grid.2x2"; case .general: return "slider.horizontal.3"; case .destinations: return "globe"; case .rules: return "arrow.triangle.branch"; case .privacy: return "hand.raised" } }
    var subtitle: String { switch self { case .overview: return "Every link, in the right place."; case .general: return "Make LinkRouter feel like second nature."; case .destinations: return "Your browsers, profiles, and email accounts."; case .rules: return "A little less choosing. A little more flow."; case .privacy: return "Your links are your business." } }
}

struct PendingLink: Identifiable {
    var id = UUID()
    var result: NormalizationResult
    var sourceBundleID: String?
    var isDemo: Bool
    var isMail: Bool { result.url.scheme?.lowercased() == "mailto" }
    var title: String { isMail ? ((try? Mailto(url: result.url))?.to.joined(separator: ", ") ?? "Email link") : (result.url.host ?? result.url.absoluteString) }
}

@MainActor final class AppModel: ObservableObject {
    @Published var page: SettingsPage = .overview
    @Published var config = Configuration()
    @Published var demoConfig = Configuration()
    @Published var isDemo = true
    @Published var discovered: [Destination] = [.copy]
    @Published var discoveryNotices: [String] = []
    @Published var didDiscover = false
    @Published var pending: PendingLink?
    @Published var pickerError: String?
    @Published var toast: String?
    @Published var storageError: String?
    @Published var showOnboarding = false
    @Published var editingRule: RoutingRule?
    @Published var showRuleEditor = false
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var handlerStatus: [String: Bool] = [:]
    @Published var isLaunching = false
    var presentPicker: (() -> Void)?
    var closePicker: (() -> Void)?
    var showSettings: (() -> Void)?
    private var database: ConfigurationStore?
    private var toastTask: Task<Void, Never>?

    init() {
        demoConfig.rules = Samples.rules
        demoConfig.preferences.confirmedAccountIDs = Set(Samples.destinations.filter { $0.kind == .gmail }.map(\.id))
        if CommandLine.arguments.contains("--ui-smoke") {
            database = try? ConfigurationStore(path: ":memory:")
            return
        }
        do {
            let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("LinkRouter")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            database = try ConfigurationStore(path: folder.appendingPathComponent("settings.sqlite").path)
            config = try database!.load()
        } catch { storageError = "Settings could not be loaded: \(error.localizedDescription)" }
        isDemo = !config.preferences.completedOnboarding || CommandLine.arguments.contains("--demo")
        refreshHandlers()
    }
    var current: Configuration { isDemo ? demoConfig : config }
    var preferences: Preferences { current.preferences }
    var rules: [RoutingRule] { current.rules }
    var allDestinations: [Destination] {
        var values = isDemo ? Samples.destinations : discovered
        for d in current.manualAccounts where !values.contains(where: { $0.id == d.id }) { values.insert(d, at: 0) }
        return values
    }
    var destinations: [Destination] { allDestinations.filter { !preferences.hiddenDestinationIDs.contains($0.id) } }
    var pickerDestinations: [Destination] {
        var values = pending?.isDemo == true ? Samples.destinations : availableRealDestinations
        if pending?.isDemo == true { for d in demoConfig.manualAccounts where !values.contains(where: { $0.id == d.id }) { values.append(d) } }
        return values.filter { pending?.isMail == true ? $0.supportsEmail : $0.supportsWeb }
    }
    var availableRealDestinations: [Destination] {
        var values = discovered
        for d in config.manualAccounts where !values.contains(where: { $0.id == d.id }) { values.append(d) }
        return values.filter { !config.preferences.hiddenDestinationIDs.contains($0.id) }
    }
    func change(_ body: (inout Configuration) -> Void) {
        if isDemo { body(&demoConfig) } else { body(&config); save() }
    }
    func save() {
        do { guard let database else { return }; try database.save(config) }
        catch { storageError = "Settings could not be saved: \(error.localizedDescription)" }
    }
    func discover() {
        let result = BrowserDiscovery.discover()
        discovered = result.destinations; discoveryNotices = result.notices; didDiscover = true
    }
    func useRealWorkspace() { isDemo = false; if !didDiscover { discover() } }
    func refreshHandlers() {
        for scheme in ["http", "https", "mailto"] {
            let url = URL(string: scheme == "mailto" ? "mailto:hello@example.com" : "\(scheme)://example.com")!
            let app = NSWorkspace.shared.urlForApplication(toOpen: url)
            handlerStatus[scheme] = app.flatMap { Bundle(url: $0)?.bundleIdentifier } == BrowserLauncher.bundleID
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
    func makeDefault(email: Bool) {
        Task {
            do { for scheme in email ? ["mailto"] : ["http", "https"] { try await BrowserLauncher.setDefault(scheme: scheme) }; notify("Default handler updated") }
            catch { notify(error.localizedDescription) }
            refreshHandlers()
        }
    }
    func toggleLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            refreshHandlers()
            if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        } catch { notify(error.localizedDescription); refreshHandlers() }
    }
    func test(_ text: String) { receive(text, demo: isDemo, forcePicker: true) }
    func receive(_ text: String, source: String? = nil, demo: Bool = false, forcePicker: Bool = false) {
        let forced = forcePicker || NSEvent.modifierFlags.contains(.option)
        guard let url = URL(string: text), ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") else { notify("LinkRouter supports web and email links."); return }
        if url.scheme?.lowercased() == "mailto" { do { _ = try Mailto(url: url) } catch { notify(error.localizedDescription); return } }
        if !demo && !didDiscover { discover() }
        let prefs = demo ? demoConfig.preferences : config.preferences
        let result = URLNormalizer().normalize(url, stripTracking: prefs.stripTracking, unwrapRedirects: prefs.unwrapRedirects)
        let link = PendingLink(result: result, sourceBundleID: source, isDemo: demo)
        let context = RoutingContext(url: result.url, sourceBundleID: source, forcePicker: forced)
        let values = demo ? Samples.destinations : availableRealDestinations
        let destination = RuleEngine().destination(for: context, rules: demo ? demoConfig.rules : config.rules, preferences: prefs, available: values)
        if let destination, destination.kind != .gmail || prefs.confirmedAccountIDs.contains(destination.id) {
            Task { await open(destination, link: link) }
        } else {
            // New incoming links are serialized by keeping the current picker until its decision completes.
            if pending != nil { queue.append(link); return }
            pending = link; pickerError = nil; presentPicker?()
        }
    }
    private var queue: [PendingLink] = []
    func dismissPicker() {
        pending = nil; pickerError = nil; closePicker?()
        if !queue.isEmpty { pending = queue.removeFirst(); presentPicker?() }
    }
    func choose(_ destination: Destination, remember: Bool, scope: RuleScope) async {
        guard let link = pending, !isLaunching else { return }
        let success = await open(destination, link: link)
        guard success else { return }
        if remember {
            let pattern: String?
            switch scope {
            case .website: pattern = link.result.url.host
            case .emailDomain: pattern = (try? Mailto(url: link.result.url))?.recipientDomain
            case .sourceApp: pattern = link.sourceBundleID
            }
            if let pattern {
                let rule = RoutingRule(scope: scope, pattern: pattern, destinationID: destination.id)
                if link.isDemo { demoConfig.rules.removeAll { $0.scope == scope && $0.pattern == pattern }; demoConfig.rules.append(rule) }
                else { config.rules.removeAll { $0.scope == scope && $0.pattern == pattern }; config.rules.append(rule); save() }
            }
        }
        dismissPicker()
    }
    @discardableResult func open(_ destination: Destination, link: PendingLink) async -> Bool {
        isLaunching = true; defer { isLaunching = false }
        if link.isDemo { notify("Demo: \(destination.kind == .copy ? "copied" : "opened in") \(destination.name) · \(destination.detail)"); return true }
        do { try await BrowserLauncher.launch(link.result.url, destination: destination); notify(destination.kind == .copy ? "Copied to clipboard" : "Opened in \(destination.name)"); return true }
        catch {
            if pending == nil { pending = link; presentPicker?() }
            pickerError = error.localizedDescription
            return false
        }
    }
    func copyPending(addressOnly: Bool = false) {
        guard let link = pending else { return }
        let text = addressOnly ? ((try? Mailto(url: link.result.url))?.to.joined(separator: ", ") ?? link.result.url.absoluteString) : link.result.url.absoluteString
        if !link.isDemo { BrowserLauncher.copy(text) }
        notify(link.isDemo ? "Demo: copied to clipboard" : "Copied to clipboard"); dismissPicker()
    }
    func saveRule(_ rule: RoutingRule) {
        change { value in if let index = value.rules.firstIndex(where: { $0.id == rule.id }) { value.rules[index] = rule } else { value.rules.append(rule) } }
    }
    func addAccount(email: String, profile: Destination) {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let bundle = profile.bundleID, profile.kind == .browser, bundle == "com.google.Chrome", email.contains("@"), !email.contains(where: { $0.isWhitespace }), !email.contains(",") else { return }
        let d = Destination(id: "\(bundle)|\(profile.profile ?? "Default")|\(email.lowercased())", name: email, detail: "Gmail · Chrome / \(profile.detail)", kind: .gmail, bundleID: bundle, profile: profile.profile, email: email, isSample: isDemo)
        change { value in if !value.manualAccounts.contains(where: { $0.id == d.id }) { value.manualAccounts.append(d) } }
        notify("Account added. Check the sender in Gmail before sending.")
    }
    func notify(_ message: String) {
        toastTask?.cancel(); toast = message
        toastTask = Task { try? await Task.sleep(for: .seconds(4)); if !Task.isCancelled { toast = nil } }
    }
}
