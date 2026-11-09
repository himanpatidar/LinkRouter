#if DEBUG
import AppKit
import SwiftUI
import LinkRouterCore

extension AppDelegate {
    /// Exercises the real SwiftUI/AppKit surfaces with an isolated in-memory store.
    /// Captures only this app's views, never other windows or browser data.
    func runUISmoke() async {
        do {
            let directory = URL(fileURLWithPath: CommandLine.arguments.last ?? "/tmp/LinkRouter-UI")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var checks: [String] = []
            func settle() async { try? await Task.sleep(for: .milliseconds(350)) }
            func capture(_ view: NSView, _ name: String) throws {
                view.layoutSubtreeIfNeeded()
                guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw NSError(domain: "Screenshot", code: 1) }
                view.cacheDisplay(in: view.bounds, to: rep)
                try rep.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name + ".png"))
            }
            func require(_ condition: Bool, _ name: String) throws {
                guard condition else { throw NSError(domain: "UI smoke: \(name)", code: 1) }; checks.append(name)
            }
            let main = NSApp.windows.first { $0.title == "LinkRouter" }!
            main.setContentSize(NSSize(width: 1100, height: 820))
            for page in SettingsPage.allCases {
                model.page = page; await settle(); try capture(main.contentView!, page.rawValue.lowercased())
            }
            model.page = .overview
            NSApp.appearance = NSAppearance(named: .aqua)
            await settle(); try capture(main.contentView!, "overview-light")
            NSApp.appearance = nil
            model.test(Samples.safeLink); await settle()
            try require(model.pending?.result.url.absoluteString == "https://northwind.co/pricing", "Clean URL reaches picker")
            let picker = NSApp.windows.first { $0 is PickerPanel }!
            try capture(picker.contentView!, "picker")
            let rulesBefore = model.demoConfig.rules.count
            await model.choose(Samples.destinations[0], remember: true, scope: .website)
            try require(model.pending == nil, "Choice dismisses picker")
            try require(model.demoConfig.rules.count == rulesBefore + 1, "Explicit Remember creates rule")
            model.receive(Samples.safeLink, demo: true)
            await settle()
            try require(model.pending == nil, "Remembered rule bypasses picker")
            model.test(Samples.safeLink); await settle()
            try require(model.pending != nil, "Forced picker overrides remembered rule")
            model.dismissPicker()
            model.test(Samples.links[3].url); await settle()
            try require(model.pickerDestinations.contains(where: { $0.kind == .gmail }), "Email picker offers Gmail")
            try require(!model.pickerDestinations.contains(where: { $0.kind == .browser }), "Email picker excludes web-only destinations")
            try capture(picker.contentView!, "email-picker")
            let key = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: picker.windowNumber, context: nil, characters: "1", charactersIgnoringModifiers: "1", isARepeat: false, keyCode: 18)!
            NSApp.postEvent(key, atStart: false)
            await settle(); try require(model.pending == nil, "Number key selects destination")
            model.test(Samples.safeLink); model.test(Samples.links[1].url); await settle()
            model.dismissPicker(); await settle()
            try require(model.pending?.result.url.host == "linear.app", "Consecutive incoming links are queued")
            let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: picker.windowNumber, context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53)!
            NSApp.postEvent(escape, atStart: false)
            await settle(); try require(model.pending == nil, "Escape closes picker")
            let rule = model.demoConfig.rules[0]
            model.saveRule(.init(id: rule.id, scope: .website, pattern: "edited.example.com", destinationID: "sample.personal"))
            try require(model.demoConfig.rules.first?.pattern == "edited.example.com", "Rule edits update state")
            let welcome = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 550, height: 560), styleMask: [.borderless], backing: .buffered, defer: false)
            welcome.contentView = NSHostingView(rootView: OnboardingView().environmentObject(model)); welcome.orderFront(nil)
            await settle(); try capture(welcome.contentView!, "onboarding"); welcome.orderOut(nil)
            let report: [String: Any] = ["passed": checks.count, "checks": checks, "screenshots": ["overview", "overview-light", "general", "destinations", "rules", "privacy", "picker", "email-picker", "onboarding"]]
            let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: directory.appendingPathComponent("results.json"))
            print(String(data: data, encoding: .utf8)!)
            NSApp.terminate(nil)
        } catch { fputs("UI smoke failed: \(error)\n", stderr); exit(1) }
    }
}
#endif
