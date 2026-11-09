import Testing
import Foundation
@testable import LinkRouterCore

// Small assertion adapters keep comparisons readable while using Swift Testing,
// which ships with the Command Line Tools (XCTest requires full Xcode).
private func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T) { #expect(a == b) }
private func XCTAssertTrue(_ value: Bool) { #expect(value) }
private func XCTAssertFalse(_ value: Bool, _ message: String = "") { #expect(!value, "\(message)") }
private func XCTAssertNil<T>(_ value: T?) { #expect(value == nil) }
private func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T) {
    do { _ = try expression(); Issue.record("Expected an error") } catch { }
}

struct URLNormalizerTests {
    let cleaner = URLNormalizer()
    @Test func testOutlookWrapperAndTrackers() {
        let result = cleaner.normalize(URL(string: Samples.safeLink)!)
        XCTAssertEqual(result.url.absoluteString, "https://northwind.co/pricing")
        XCTAssertEqual(result.wrappers, ["Outlook Safe Links"])
        XCTAssertEqual(result.removedParameters, ["utm_source", "utm_medium"])
    }
    @Test func testPreservesQueryBytesAndFragment() {
        let result = cleaner.normalize(URL(string: "https://example.com/search?q=a+b%20c&x=%2f&x=two&utm_source=mail#chapter%202")!)
        XCTAssertEqual(result.url.absoluteString, "https://example.com/search?q=a+b%20c&x=%2f&x=two#chapter%202")
    }
    @Test func testNestedRedirects() {
        var c = URLComponents(string: "https://slack-redir.net/link")!
        c.queryItems = [.init(name: "url", value: Samples.safeLink)]
        let result = cleaner.normalize(c.url!)
        XCTAssertEqual(result.url.absoluteString, "https://northwind.co/pricing")
        XCTAssertEqual(result.wrappers.count, 2)
    }
    @Test func testGoogleAndNewsletterAllowlist() {
        for host in ["www.google.com/url?q=", "buttondown.email/redirect?url="] {
            XCTAssertEqual(cleaner.normalize(URL(string: "https://\(host)https%3A%2F%2Fexample.com%2Fpage")!).url.absoluteString, "https://example.com/page")
        }
    }
    @Test func testDoesNotUnwrapSpoofedOrUnknownHosts() {
        for host in ["safelinks.protection.outlook.com.evil.com", "evilgoogle.com", "click.unknown-newsletter.com"] {
            let url = URL(string: "https://\(host)/url?url=https%3A%2F%2Fexample.com&q=https%3A%2F%2Fexample.com")!
            XCTAssertEqual(cleaner.normalize(url).url, url)
        }
    }
    @Test func testRejectsDangerousOrCredentialedDestinations() {
        for target in ["javascript:alert(1)", "file:///etc/passwd", "https://user:secret@example.com/", "//example.com/path"] {
            var c = URLComponents(string: "https://slack-redir.net/link")!
            c.queryItems = [.init(name: "url", value: target)]
            XCTAssertEqual(cleaner.normalize(c.url!).url, c.url!)
        }
    }
    @Test func testSignedURLIsUntouched() {
        for signature in ["X-Amz-Signature", "signature", "sig", "X-Goog-Signature"] {
            let url = URL(string: "https://example.com/download?utm_source=required&\(signature)=abc%2Bdef")!
            XCTAssertEqual(cleaner.normalize(url).url.absoluteString, url.absoluteString)
        }
    }
    @Test func testYouTubeShareOnlyRemovesSIOnYouTube() {
        XCTAssertEqual(cleaner.normalize(URL(string: "https://youtu.be/abc?si=tracking&t=42#clip")!).url.absoluteString, "https://youtu.be/abc?t=42#clip")
        let url = URL(string: "https://example.com/?si=meaningful&mc_custom=keep")!
        XCTAssertEqual(cleaner.normalize(url).url, url)
    }
    @Test func testOptionsIndependentlyDisableStages() {
        let wrapped = URL(string: Samples.safeLink)!
        XCTAssertEqual(cleaner.normalize(wrapped, unwrapRedirects: false).url, wrapped)
        let result = cleaner.normalize(wrapped, stripTracking: false)
        XCTAssertEqual(result.url.absoluteString, "https://northwind.co/pricing?utm_source=outlook&utm_medium=email")
    }
    @Test func testMailtoIsNeverCleaned() {
        let url = URL(string: "mailto:hello@example.com?body=https%3A%2F%2Fx.com%3Futm_source%3Dkeep&subject=a+b")!
        XCTAssertEqual(cleaner.normalize(url).url.absoluteString, url.absoluteString)
    }
    @Test func testIdempotence() {
        let first = cleaner.normalize(URL(string: Samples.safeLink)!)
        XCTAssertEqual(cleaner.normalize(first.url).url, first.url)
    }
}

struct MailtoTests {
    @Test func testAllFieldsAndLiteralPlus() throws {
        let mail = try Mailto(url: URL(string: "mailto:maya%2Bwork@northwind.co,hello@example.com?cc=copy@example.com&bcc=private@example.com&subject=A%20%26%20B%20%2B%20C&body=Hello%0D%0AWorld%20%26%20you%2Bme")!)
        XCTAssertEqual(mail.to, ["maya+work@northwind.co", "hello@example.com"])
        XCTAssertEqual(mail.cc, ["copy@example.com"])
        XCTAssertEqual(mail.bcc, ["private@example.com"])
        XCTAssertEqual(mail.subject, "A & B + C")
        XCTAssertEqual(mail.body, "Hello\r\nWorld & you+me")
        XCTAssertNil(mail.recipientDomain)
        let c = URLComponents(url: try mail.gmailURL(account: "maya+work@northwind.co"), resolvingAgainstBaseURL: false)!
        let fields = Dictionary(uniqueKeysWithValues: c.queryItems!.map { ($0.name, $0.value!) })
        XCTAssertEqual(fields["authuser"], "maya+work@northwind.co")
        XCTAssertEqual(fields["to"], mail.to.joined(separator: ","))
        XCTAssertEqual(fields["cc"], mail.cc.joined(separator: ","))
        XCTAssertEqual(fields["bcc"], mail.bcc.joined(separator: ","))
        XCTAssertEqual(fields["su"], mail.subject)
        XCTAssertEqual(fields["body"], mail.body)
        XCTAssertTrue(try mail.gmailURL(account: "maya+work@northwind.co").absoluteString.contains("%2B"))
    }
    @Test func testQueryRecipientsEmptyPathUnicodeAndRepeatedCC() throws {
        let mail = try Mailto(url: URL(string: "mailto:?to=one@northwind.co&cc=two@northwind.co&CC=three@northwind.co&subject=Caf%C3%A9%20%E2%9C%93&body=%2520")!)
        XCTAssertEqual(mail.to, ["one@northwind.co"])
        XCTAssertEqual(mail.cc.count, 2)
        XCTAssertEqual(mail.subject, "Café ✓")
        XCTAssertEqual(mail.body, "%20")
        XCTAssertEqual(mail.recipientDomain, "northwind.co")
    }
    @Test func testLiteralPlusNotFormDecoded() throws {
        let mail = try Mailto(url: URL(string: "mailto:a+b@example.com?subject=a+b&body=x+y")!)
        XCTAssertEqual(mail.to, ["a+b@example.com"]); XCTAssertEqual(mail.subject, "a+b"); XCTAssertEqual(mail.body, "x+y")
    }
    @Test func testRejectsHeaderInjection() {
        for text in ["mailto:a@example.com%0D%0ABcc:b@example.com", "mailto:a@example.com?subject=test%0ABcc%3Ab@example.com", "https://example.com"] { XCTAssertThrowsError(try Mailto(url: URL(string: text)!)) }
    }
    @Test func testComposeMayHaveNoRecipient() throws {
        let mail = try Mailto(url: URL(string: "mailto:?subject=Hello")!)
        XCTAssertNil(mail.recipientDomain)
        XCTAssertEqual(URLComponents(url: try mail.gmailURL(account: "a@example.com"), resolvingAgainstBaseURL: false)?.host, "mail.google.com")
    }
}

struct RuleEngineTests {
    let work = Samples.destinations[0]
    let personal = Samples.destinations[1]
    let gmail = Samples.destinations[3]
    let engine = RuleEngine()
    func resolve(_ url: String, _ rules: [RoutingRule], prefs: Preferences = Preferences(), source: String? = nil, forced: Bool = false) -> Destination? {
        engine.destination(for: .init(url: URL(string: url)!, sourceBundleID: source, forcePicker: forced), rules: rules, preferences: prefs, available: Samples.destinations)
    }
    @Test func testForcedPickerOverridesAll() {
        XCTAssertNil(resolve("https://figma.com", Samples.rules, forced: true))
    }
    @Test func testExactWebsiteBeforeWildcardAndAppAndDefault() {
        var prefs = Preferences(); prefs.defaultWebID = "sample.safari"
        let rules = [RoutingRule(scope: .sourceApp, pattern: "com.slack", destinationID: personal.id), .init(scope: .website, pattern: "*.figma.com", destinationID: personal.id), .init(scope: .website, pattern: "www.figma.com", destinationID: work.id)]
        XCTAssertEqual(resolve("https://www.figma.com/a", rules, prefs: prefs, source: "com.slack"), work)
    }
    @Test func testEmailDomainBeforeSourceApp() {
        let rules = [RoutingRule(scope: .sourceApp, pattern: "com.slack", destinationID: "sample.mail"), .init(scope: .emailDomain, pattern: "northwind.co", destinationID: gmail.id)]
        XCTAssertEqual(resolve("mailto:a@northwind.co", rules, source: "com.slack"), gmail)
    }
    @Test func testNoAppGuessWhenContextMissing() {
        XCTAssertNil(resolve("https://example.com", [.init(scope: .sourceApp, pattern: "com.slack", destinationID: work.id)]))
    }
    @Test func testWildcardBoundaries() {
        let rules = [RoutingRule(scope: .website, pattern: "*.example.com", destinationID: work.id)]
        XCTAssertEqual(resolve("https://docs.example.com", rules), work)
        XCTAssertNil(resolve("https://example.com", rules))
        XCTAssertNil(resolve("https://notexample.com", rules))
        XCTAssertNil(resolve("https://example.com.evil.test", rules))
    }
    @Test func testDisabledMissingAndIncompatibleTargetsAreSkipped() {
        let rules = [RoutingRule(scope: .website, pattern: "figma.com", destinationID: "gone"), .init(scope: .website, pattern: "figma.com", destinationID: gmail.id), .init(scope: .website, pattern: "figma.com", destinationID: personal.id, enabled: false), .init(scope: .website, pattern: "figma.com", destinationID: work.id)]
        XCTAssertEqual(resolve("https://figma.com", rules), work)
    }
    @Test func testRuleOrderBreaksTies() {
        let rules = [RoutingRule(scope: .website, pattern: "figma.com", destinationID: personal.id), .init(scope: .website, pattern: "figma.com", destinationID: work.id)]
        XCTAssertEqual(resolve("https://figma.com", rules), personal)
    }
    @Test func testSeparateWebAndMailDefaults() {
        var prefs = Preferences(); prefs.defaultWebID = work.id; prefs.defaultMailID = gmail.id
        XCTAssertEqual(resolve("https://example.com", [], prefs: prefs), work)
        XCTAssertEqual(resolve("mailto:a@example.com", [], prefs: prefs), gmail)
        XCTAssertNil(resolve("https://example.com", []))
    }
    @Test func testMultiDomainEmailSkipsRecipientRule() {
        XCTAssertNil(resolve("mailto:a@northwind.co,b@other.com", Samples.rules))
    }
    @Test func testRulePatternValidation() {
        XCTAssertTrue(RoutingRule.validPattern("*.figma.com", scope: .website))
        for pattern in ["", "https://figma.com", "figma..com", "figma.com/path", "-bad.com", "figma.com.", "*.com"] {
            XCTAssertFalse(RoutingRule.validPattern(pattern, scope: .website), pattern)
        }
        XCTAssertFalse(RoutingRule.validPattern("*.figma.com", scope: .emailDomain))
    }
}

struct ConfigurationStoreTests {
    @Test func testSQLiteRoundTripAcrossConnections() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("test.sqlite").path
        var value = Configuration(); value.rules = Samples.rules; value.preferences.stripTracking = false
        value.preferences.confirmedAccountIDs.insert("an-account"); value.manualAccounts = [Samples.destinations[3]]
        do { let store = try ConfigurationStore(path: path); XCTAssertEqual(try store.load(), Configuration()); try store.save(value) }
        let store = try ConfigurationStore(path: path)
        XCTAssertEqual(try store.load(), value)
        value.rules.removeFirst(); try store.save(value)
        XCTAssertEqual(try store.load().rules.count, 2)
        let permissions = try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue, 0o600)
    }
}
