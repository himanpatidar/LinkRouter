import Foundation

public enum DestinationKind: String, Codable { case browser, gmail, mailApp, copy }

public struct Destination: Identifiable, Codable, Equatable, Hashable {
    public var id: String
    public var name: String
    public var detail: String
    public var kind: DestinationKind
    public var bundleID: String?
    public var profile: String?
    public var email: String?
    public var isSample: Bool
    public init(id: String, name: String, detail: String, kind: DestinationKind, bundleID: String? = nil, profile: String? = nil, email: String? = nil, isSample: Bool = false) {
        self.id = id; self.name = name; self.detail = detail; self.kind = kind
        self.bundleID = bundleID; self.profile = profile; self.email = email; self.isSample = isSample
    }
    public var supportsWeb: Bool { kind == .browser || kind == .copy }
    public var supportsEmail: Bool { kind == .gmail || kind == .mailApp || kind == .copy }
    public static let copy = Destination(id: "copy", name: "Copy link", detail: "To your clipboard", kind: .copy)
}

public enum RuleScope: String, Codable, CaseIterable { case website, emailDomain, sourceApp
    public var title: String { switch self { case .website: return "Website"; case .emailDomain: return "Email domain"; case .sourceApp: return "Source app" } }
}

public struct RoutingRule: Identifiable, Codable, Equatable {
    public var id: UUID
    public var scope: RuleScope
    public var pattern: String
    public var destinationID: String
    public var enabled: Bool
    public init(id: UUID = UUID(), scope: RuleScope, pattern: String, destinationID: String, enabled: Bool = true) {
        self.id = id; self.scope = scope; self.pattern = pattern.lowercased(); self.destinationID = destinationID; self.enabled = enabled
    }
    public static func validPattern(_ input: String, scope: RuleScope) -> Bool {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if scope == .sourceApp { return value.contains(".") && value.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "-") } }
        let domain = value.hasPrefix("*.") && scope == .website ? String(value.dropFirst(2)) : value
        return domain.count <= 253 && domain.contains(".") && domain.split(separator: ".", omittingEmptySubsequences: false).allSatisfy {
            !$0.isEmpty && $0.count <= 63 && $0.first != "-" && $0.last != "-" && $0.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
        }
    }
}

public struct Preferences: Codable, Equatable {
    public var stripTracking = true
    public var unwrapRedirects = true
    public var defaultWebID: String? = nil
    public var defaultMailID: String? = nil
    public var completedOnboarding = false
    public var confirmedAccountIDs: Set<String> = []
    public var hiddenDestinationIDs: Set<String> = []
    public init() {}
}

public struct Configuration: Codable, Equatable {
    public var preferences = Preferences()
    public var rules: [RoutingRule] = []
    public var manualAccounts: [Destination] = []
    public init() {}
}

public enum Samples {
    public static let destinations: [Destination] = [
        .init(id: "sample.work", name: "Google Chrome", detail: "Northwind · Work", kind: .browser, bundleID: "com.google.Chrome", profile: "Profile 1", isSample: true),
        .init(id: "sample.personal", name: "Google Chrome", detail: "Personal", kind: .browser, bundleID: "com.google.Chrome", profile: "Default", isSample: true),
        .init(id: "sample.safari", name: "Safari", detail: "Default profile", kind: .browser, bundleID: "com.apple.Safari", isSample: true),
        .init(id: "sample.gmail.work", name: "maya@northwind.co", detail: "Gmail · Chrome / Northwind", kind: .gmail, bundleID: "com.google.Chrome", profile: "Profile 1", email: "maya@northwind.co", isSample: true),
        .init(id: "sample.gmail.personal", name: "maya@example.com", detail: "Gmail · Chrome / Personal", kind: .gmail, bundleID: "com.google.Chrome", profile: "Default", email: "maya@example.com", isSample: true),
        .init(id: "sample.mail", name: "Apple Mail", detail: "Default sending account", kind: .mailApp, bundleID: "com.apple.mail", isSample: true),
        .copy
    ]
    public static let rules: [RoutingRule] = [
        .init(scope: .website, pattern: "figma.com", destinationID: "sample.work"),
        .init(scope: .emailDomain, pattern: "northwind.co", destinationID: "sample.gmail.work"),
        .init(scope: .website, pattern: "*.notion.so", destinationID: "sample.work")
    ]
    public static let safeLink = "https://nam01.safelinks.protection.outlook.com/?url=https%3A%2F%2Fnorthwind.co%2Fpricing%3Futm_source%3Doutlook%26utm_medium%3Demail&data=example"
    public static let links: [(name: String, subtitle: String, url: String, icon: String)] = [
        ("Outlook Safe Links", "A wrapped link, with two trackers", safeLink, "shield.lefthalf.filled"),
        ("Google result", "The destination, without the detour", "https://www.google.com/url?q=https%3A%2F%2Flinear.app%2Ffeatures%3Futm_source%3Dgoogle&sa=D", "magnifyingglass"),
        ("YouTube share", "Keep the video. Leave the tracking.", "https://youtu.be/dQw4w9WgXcQ?si=sample-tracker&t=42", "play.rectangle"),
        ("Email to Northwind", "Compose from the account you choose", "mailto:hello@northwind.co?subject=Let%27s%20talk&body=Hello%20Northwind%2C", "envelope")
    ]
}
