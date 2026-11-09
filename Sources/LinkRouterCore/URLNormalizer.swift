import Foundation

public struct NormalizationResult: Equatable {
    public var original: URL
    public var url: URL
    public var wrappers: [String]
    public var removedParameters: [String]
    public var summary: String {
        var parts: [String] = []
        if !wrappers.isEmpty { parts.append("Unwrapped \(wrappers.count == 1 ? "redirect" : "\(wrappers.count) redirects")") }
        if !removedParameters.isEmpty { parts.append("Removed \(removedParameters.count) tracking parameter\(removedParameters.count == 1 ? "" : "s")") }
        return parts.isEmpty ? "This link is already clean" : parts.joined(separator: " · ")
    }
}

public struct URLNormalizer {
    public init() {}
    public func normalize(_ original: URL, stripTracking: Bool = true, unwrapRedirects: Bool = true) -> NormalizationResult {
        var result = NormalizationResult(original: original, url: original, wrappers: [], removedParameters: [])
        guard ["http", "https"].contains(original.scheme?.lowercased() ?? "") else { return result }
        var visited: Set<String> = [original.absoluteString]
        if unwrapRedirects {
            for _ in 0..<5 {
                guard let (url, label) = unwrap(result.url), !visited.contains(url.absoluteString) else { break }
                visited.insert(url.absoluteString); result.url = url; result.wrappers.append(label)
            }
        }
        guard stripTracking, var components = URLComponents(url: result.url, resolvingAgainstBaseURL: false), let query = components.percentEncodedQuery else { return result }
        let fields = query.components(separatedBy: "&")
        let keys = fields.map { String($0.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)[0]).removingPercentEncoding?.lowercased() ?? "" }
        // Signed URLs must remain byte-for-byte intact; analytics-looking fields may be part of the signature.
        let signatures: Set<String> = ["signature", "sig", "x-amz-signature", "x-goog-signature", "policy", "key-pair-id"]
        guard signatures.isDisjoint(with: keys) else { return result }
        let known: Set<String> = ["gclid", "dclid", "fbclid", "msclkid", "mc_cid", "mc_eid", "_hsenc", "_hsmi", "igshid", "gbraid", "wbraid"]
        let host = components.host?.lowercased() ?? ""
        var kept: [String] = []
        for (field, key) in zip(fields, keys) {
            let youtubeShare = key == "si" && (host == "youtu.be" || host == "youtube.com" || host == "www.youtube.com")
            if key.hasPrefix("utm_") || known.contains(key) || youtubeShare { result.removedParameters.append(key) }
            else { kept.append(field) }
        }
        if !result.removedParameters.isEmpty {
            components.percentEncodedQuery = kept.isEmpty ? nil : kept.joined(separator: "&")
            if let cleaned = components.url { result.url = cleaned }
        }
        return result
    }
    private func unwrap(_ url: URL) -> (URL, String)? {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false), let host = c.host?.lowercased() else { return nil }
        var key: String?; var label = "Redirect"
        if host == "safelinks.protection.outlook.com" || host.hasSuffix(".safelinks.protection.outlook.com") { key = "url"; label = "Outlook Safe Links" }
        else if ["www.google.com", "google.com", "www.google.co.uk", "www.google.co.in", "www.google.de", "www.google.fr"].contains(host) && c.path == "/url" {
            key = c.queryItems?.contains(where: { $0.name == "q" }) == true ? "q" : "url"; label = "Google redirect"
        } else if host == "slack-redir.net" && c.path == "/link" { key = "url"; label = "Slack redirect" }
        else if ["links.buttondown.email", "buttondown.email"].contains(host) && c.path == "/redirect" { key = "url"; label = "Newsletter redirect" }
        guard let key, let value = c.queryItems?.first(where: { $0.name == key })?.value,
              let target = URL(string: value), ["http", "https"].contains(target.scheme?.lowercased() ?? ""),
              let targetHost = target.host, !targetHost.isEmpty, target.user == nil, target.password == nil else { return nil }
        return (target, label)
    }
}
