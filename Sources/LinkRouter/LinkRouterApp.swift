import AppKit
import SwiftUI
import Carbon
import LinkRouterCore

@main struct LinkRouterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}

final class PickerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = AppModel()
    private var window: NSWindow?
    private var panel: PickerPanel?
    private var statusItem: NSStatusItem?
    private var keyMonitor: Any?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleURL(_:reply:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model.presentPicker = { [weak self] in self?.showPicker() }
        model.closePicker = { [weak self] in self?.panel?.orderOut(nil) }
        model.showSettings = { [weak self] in self?.openSettings() }
        setupMenu()
        #if DEBUG
        if CommandLine.arguments.contains("--ui-smoke") {
            openSettings()
            Task { await runUISmoke() }
            return
        }
        #endif
        if CommandLine.arguments.contains("--demo") || !model.config.preferences.completedOnboarding { openSettings() }
        if CommandLine.arguments.contains("--onboarding") { model.showOnboarding = true }
        if let index = CommandLine.arguments.firstIndex(of: "--test-url"), CommandLine.arguments.indices.contains(index + 1) { model.test(CommandLine.arguments[index + 1]) }
        // URL events can arrive before launch finishes and before the panel callback exists.
        if model.pending != nil { showPicker() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { openSettings(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    @objc func handleURL(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let value = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue else { return }
        let pid = event.attributeDescriptor(forKeyword: AEKeyword(keySenderPIDAttr))?.int32Value
        var source = pid.flatMap { NSRunningApplication(processIdentifier: $0)?.bundleIdentifier }
        if [BrowserLauncher.bundleID, "com.apple.coreservices.launchservicesd", "com.apple.loginwindow"].contains(source ?? "") { source = nil }
        model.receive(value, source: source)
    }
    func setupMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "LinkRouter")
        let menu = NSMenu()
        menu.addItem(withTitle: "LinkRouter", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        addItem("Open LinkRouter…", action: #selector(openSettings), key: ",", to: menu)
        addItem("Route clipboard link…", action: #selector(routeClipboard), key: "", to: menu)
        addItem("Try sample picker", action: #selector(samplePicker), key: "", to: menu)
        menu.addItem(.separator())
        addItem("Quit LinkRouter", action: #selector(quit), key: "q", to: menu)
        item.menu = menu; statusItem = item
    }
    func addItem(_ title: String, action: Selector, key: String, to menu: NSMenu) { let item = NSMenuItem(title: title, action: action, keyEquivalent: key); item.target = self; menu.addItem(item) }
    @objc func openSettings() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 800), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            w.title = "LinkRouter"; w.titleVisibility = .hidden; w.titlebarAppearsTransparent = true
            w.isReleasedWhenClosed = false; w.minSize = NSSize(width: 930, height: 680)
            w.contentView = NSHostingView(rootView: SettingsView().environmentObject(model))
            w.delegate = self; w.center(); window = w
        }
        NSApp.activate(ignoringOtherApps: true); window?.makeKeyAndOrderFront(nil)
    }
    func showPicker() {
        if panel == nil {
            let p = PickerPanel(contentRect: NSRect(x: 0, y: 0, width: 390, height: 450), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.isFloatingPanel = true; p.level = .floating; p.hasShadow = true; p.isOpaque = false
            p.backgroundColor = .clear; p.hidesOnDeactivate = false; p.isReleasedWhenClosed = false
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let hosting = NSHostingView(rootView: PickerView().environmentObject(model))
            hosting.wantsLayer = true; hosting.layer?.cornerRadius = 13; hosting.layer?.masksToBounds = true
            p.contentView = hosting; p.delegate = self; panel = p
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.panel?.isKeyWindow == true else { return event }
                let key: String
                switch event.keyCode { case 125: key = "↓"; case 126: key = "↑"; default: key = event.charactersIgnoringModifiers ?? "" }
                if ["↑", "↓", "\r", "\u{1b}", "c", "C", "1", "2", "3", "4", "5"].contains(key) {
                    NotificationCenter.default.post(name: .pickerKey, object: PickerKeystroke(key: key, flags: event.modifierFlags)); return nil
                }
                return event
            }
        }
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let height = min(CGFloat(545), visible.height - 30)
        panel.setContentSize(NSSize(width: 390, height: height))
        let x = min(max(mouse.x - 30, visible.minX + 12), visible.maxX - 402)
        let y = min(max(mouse.y - height - 12, visible.minY + 12), visible.maxY - height - 12)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        NSApp.activate(ignoringOtherApps: true); panel.makeKeyAndOrderFront(nil)
    }
    @objc func routeClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string) else { openSettings(); model.notify("Copy a link first, then try again."); return }
        model.receive(text.trimmingCharacters(in: .whitespacesAndNewlines), forcePicker: true)
    }
    func windowDidResignKey(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === panel, model.pending != nil, !model.isLaunching { model.dismissPicker() }
    }
    @objc func samplePicker() { model.receive(Samples.safeLink, demo: true, forcePicker: true) }
    @objc func quit() { NSApp.terminate(nil) }
}
