import Foundation

public struct RoutingContext {
    public var url: URL
    public var sourceBundleID: String?
    public var forcePicker: Bool
    public init(url: URL, sourceBundleID: String? = nil, forcePicker: Bool = false) {
        self.url = url; self.sourceBundleID = sourceBundleID; self.forcePicker = forcePicker
    }
}

public struct RuleEngine {
    public init() {}
    public func destination(for context: RoutingContext, rules: [RoutingRule], preferences: Preferences, available: [Destination]) -> Destination? {
        guard !context.forcePicker else { return nil }
        let isMail = context.url.scheme?.lowercased() == "mailto"
        func target(_ id: String) -> Destination? { available.first { $0.id == id && (isMail ? $0.supportsEmail : $0.supportsWeb) } }
        let active = rules.filter(\.enabled)
        let host = context.url.host?.lowercased() ?? ""
        let mailDomain = (try? Mailto(url: context.url))?.recipientDomain
        var matching: [RoutingRule] = []
        if isMail {
            if let mailDomain { matching += active.filter { $0.scope == .emailDomain && $0.pattern == mailDomain } }
        } else {
            matching += active.filter { $0.scope == .website && $0.pattern == host }
            matching += active.filter { $0.scope == .website && $0.pattern.hasPrefix("*.") && host.hasSuffix(String($0.pattern.dropFirst(1))) }
        }
        if let source = context.sourceBundleID { matching += active.filter { $0.scope == .sourceApp && $0.pattern == source.lowercased() } }
        for rule in matching { if let destination = target(rule.destinationID) { return destination } }
        if let id = isMail ? preferences.defaultMailID : preferences.defaultWebID { return target(id) }
        return nil
    }
}
