import AppKit
import LinkRouterCore
import ServiceManagement

struct DiscoveryResult {
    var destinations: [Destination] = []
    var notices: [String] = []
}

enum BrowserDiscovery {
    struct Browser { var name: String; var bundleID: String; var directory: String }
    static let chromium = [
        Browser(name: "Google Chrome", bundleID: "com.google.Chrome", directory: "Google/Chrome"),
        Browser(name: "Brave", bundleID: "com.brave.Browser", directory: "BraveSoftware/Brave-Browser"),
        Browser(name: "Microsoft Edge", bundleID: "com.microsoft.edgemac", directory: "Microsoft Edge"),
        Browser(name: "Chromium", bundleID: "org.chromium.Chromium", directory: "Chromium")
    ]
    @MainActor static func discover() -> DiscoveryResult {
        var result = DiscoveryResult()
        let support = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        for browser in chromium {
            guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleID) != nil else { continue }
            let root = support.appendingPathComponent(browser.directory)
            let state = json(root.appendingPathComponent("Local State"))
            let cache = (state?["profile"] as? [String: Any])?["info_cache"] as? [String: [String: Any]] ?? [:]
            let folders = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
            let names = Set(cache.keys).union(folders.filter { $0 == "Default" || $0.hasPrefix("Profile ") }).sorted()
            if names.isEmpty {
                result.destinations.append(.init(id: browser.bundleID, name: browser.name, detail: "Default profile", kind: .browser, bundleID: browser.bundleID))
                result.notices.append("\(browser.name): no readable profile metadata. You can still use its default profile.")
            }
            for folder in names where folder == "Default" || (folder.hasPrefix("Profile ") && !folder.contains("/")) {
                let info = cache[folder] ?? [:]
                let name = info["name"] as? String ?? folder
                let id = "\(browser.bundleID)|\(folder)"
                result.destinations.append(.init(id: id, name: browser.name, detail: name, kind: .browser, bundleID: browser.bundleID, profile: folder))
                // Local profile preferences are hints, never proof of a live Gmail session.
                if browser.bundleID == "com.google.Chrome" {
                    let prefs = json(root.appendingPathComponent(folder).appendingPathComponent("Preferences"))
                    var emails = Set<String>()
                    if let email = info["user_name"] as? String, email.contains("@") { emails.insert(email) }
                    for account in prefs?["account_info"] as? [[String: Any]] ?? [] {
                        if let email = account["email"] as? String, email.contains("@") { emails.insert(email) }
                    }
                    for email in emails.sorted() {
                        result.destinations.append(.init(id: "\(id)|\(email.lowercased())", name: email, detail: "Gmail · Chrome / \(name)", kind: .gmail, bundleID: browser.bundleID, profile: folder, email: email))
                    }
                }
            }
        }
        for (id, name) in [("com.apple.Safari", "Safari"), ("org.mozilla.firefox", "Firefox"), ("company.thebrowser.Browser", "Arc"), ("app.zen-browser.zen", "Zen")] {
            if NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) != nil {
                result.destinations.append(.init(id: id, name: name, detail: "Default profile", kind: .browser, bundleID: id))
            }
        }
        for (id, name) in [("com.apple.mail", "Apple Mail"), ("com.microsoft.Outlook", "Microsoft Outlook"), ("com.readdle.smartemail-Mac", "Spark")] {
            if NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) != nil {
                result.destinations.append(.init(id: id, name: name, detail: "Uses this app’s sending account", kind: .mailApp, bundleID: id))
            }
        }
        if var system = BrowserLauncher.systemDestination(for: URL(string: "https://example.com")!) {
            system.id = "system.web"; system.detail = "System default · \(system.name)"; system.name = "Default browser"
            result.destinations.insert(system, at: 0)
        }
        result.destinations.append(.copy)
        return result
    }
    private static func json(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url), data.count < 30_000_000 else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}

enum LaunchError: LocalizedError {
    case missing, recursion, sample
    var errorDescription: String? {
        switch self {
        case .missing: return "This browser or profile is no longer available. Choose another destination or copy the link."
        case .recursion: return "LinkRouter is the system default. Choose a browser directly to avoid a routing loop."
        case .sample: return "Sample profiles are available only in the demo."
        }
    }
}

@MainActor enum BrowserLauncher {
    static let bundleID = "co.linkrouter.mac"
    static func launch(_ url: URL, destination: Destination) async throws {
        guard !destination.isSample else { throw LaunchError.sample }
        if destination.kind == .copy {
            copy(url.scheme?.lowercased() == "mailto" ? try Mailto(url: url).to.joined(separator: ", ") : url.absoluteString)
            return
        }
        guard let id = destination.bundleID, id != bundleID else { throw LaunchError.recursion }
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { throw LaunchError.missing }
        var target = url
        if destination.kind == .gmail { target = try Mailto(url: url).gmailURL(account: destination.email ?? "") }
        if let profile = destination.profile {
            guard !profile.contains("/"), let executable = Bundle(url: app)?.executableURL else { throw LaunchError.missing }
            if let browser = BrowserDiscovery.chromium.first(where: { $0.bundleID == id }) {
                let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/\(browser.directory)/\(profile)")
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else { throw LaunchError.missing }
            }
            // Direct argv forwarding also selects the profile when Chrome is already running.
            let process = Process()
            process.executableURL = executable
            process.arguments = ["--profile-directory=\(profile)", target.absoluteString]
            process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
            try process.run()
            try await Task.sleep(for: .milliseconds(250))
            if !process.isRunning && process.terminationStatus != 0 { throw LaunchError.missing }
        } else {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            try await NSWorkspace.shared.open([target], withApplicationAt: app, configuration: config)
        }
    }
    static func copy(_ text: String) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string) }
    static func systemDestination(for url: URL) -> Destination? {
        guard let app = NSWorkspace.shared.urlForApplication(toOpen: url), let id = Bundle(url: app)?.bundleIdentifier, id != bundleID else { return nil }
        return .init(id: id, name: app.deletingPathExtension().lastPathComponent, detail: "System default", kind: url.scheme == "mailto" ? .mailApp : .browser, bundleID: id)
    }
    static func setDefault(scheme: String) async throws {
        try await NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: scheme)
    }
}
