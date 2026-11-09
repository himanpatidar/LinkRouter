import Foundation

public enum MailtoError: LocalizedError { case invalid
    public var errorDescription: String? { "This email link contains invalid addresses or headers." }
}

public struct Mailto: Equatable {
    public var to: [String]
    public var cc: [String]
    public var bcc: [String]
    public var subject: String
    public var body: String
    public init(url: URL) throws {
        guard url.scheme?.lowercased() == "mailto", let c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw MailtoError.invalid }
        func addresses(_ value: String) -> [String] { value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        to = addresses(c.path); cc = []; bcc = []; subject = ""; body = ""
        for item in c.queryItems ?? [] {
            let value = item.value ?? ""
            switch item.name.lowercased() {
            case "to": to += addresses(value)
            case "cc": cc += addresses(value)
            case "bcc": bcc += addresses(value)
            case "subject": subject = value
            case "body": body = value
            default: break
            }
        }
        guard (to + cc + bcc).allSatisfy({ $0.contains("@") && !$0.contains(where: { $0.isNewline || $0.isWhitespace }) }), !subject.contains(where: { $0.isNewline }) else { throw MailtoError.invalid }
    }
    /// Ambiguous multi-domain messages must go through the account picker.
    public var recipientDomain: String? {
        let domains = Set((to + cc + bcc).compactMap { $0.split(separator: "@").last.map { String($0).lowercased() } })
        return domains.count == 1 ? domains.first : nil
    }
    public func gmailURL(account: String) throws -> URL {
        guard account.contains("@"), !account.contains(where: { $0.isWhitespace }) else { throw MailtoError.invalid }
        var c = URLComponents(string: "https://mail.google.com/mail/")!
        var fields = [("view", "cm"), ("fs", "1"), ("authuser", account), ("to", to.joined(separator: ",")), ("cc", cc.joined(separator: ",")), ("bcc", bcc.joined(separator: ",")), ("su", subject), ("body", body)]
        fields.removeAll { $0.1.isEmpty }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        c.percentEncodedQuery = fields.map { "\($0.0)=\($0.1.addingPercentEncoding(withAllowedCharacters: allowed)!)" }.joined(separator: "&")
        guard let url = c.url else { throw MailtoError.invalid }; return url
    }
}
