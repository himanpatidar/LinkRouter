import SwiftUI
import LinkRouterCore

struct DestinationsView: View {
    @EnvironmentObject var model: AppModel
    @State private var showAccount = false
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack { SectionHeading(title: "A place for every link", detail: "Profiles stay separate, just as you left them."); Spacer(); Button { if model.isDemo { model.notify("Demo destinations are ready to try") } else { model.discover(); model.notify("Destinations refreshed") } } label: { Label("Refresh", systemImage: "arrow.clockwise") }.buttonStyle(QuietButtonStyle()) }
            if !model.isDemo && !model.didDiscover { Button("Discover browsers on this Mac") { model.discover() }.buttonStyle(PrimaryButtonStyle()) }
            destinationGroup("BROWSERS & PROFILES", values: model.allDestinations.filter { $0.kind == .browser })
            HStack { Eyebrow(text: "Email accounts"); Spacer(); Button { showAccount = true } label: { Label("Add account", systemImage: "plus") }.buttonStyle(QuietButtonStyle()).disabled(!model.allDestinations.contains { $0.bundleID == "com.google.Chrome" && $0.kind == .browser }) }
            Card(padding: 18) {
                VStack(spacing: 16) {
                    if model.allDestinations.filter({ $0.kind == .gmail }).isEmpty { Text("No Google accounts found. Add an email address to a Chrome profile to use Gmail compose.").font(.system(size: 12)).foregroundStyle(Palette.muted).frame(maxWidth: .infinity, alignment: .leading) }
                    ForEach(model.allDestinations.filter { $0.kind == .gmail }) { d in
                        HStack {
                            DestinationRow(destination: d)
                            VStack(alignment: .trailing, spacing: 6) {
                                Text(model.preferences.confirmedAccountIDs.contains(d.id) ? "Confirmed by you" : "Needs your check").font(.system(size: 9, weight: .medium)).foregroundStyle(Palette.green)
                                Toggle("Account checked", isOn: Binding(get: { model.preferences.confirmedAccountIDs.contains(d.id) }, set: { value in model.change { if value { $0.preferences.confirmedAccountIDs.insert(d.id) } else { $0.preferences.confirmedAccountIDs.remove(d.id) } } })).toggleStyle(.checkbox).font(.system(size: 10))
                            }
                        }
                        if d.id != model.allDestinations.filter({ $0.kind == .gmail }).last?.id { Divider() }
                    }
                }
            }
            Label("Chrome metadata can be incomplete or stale. Confirm the sender in Gmail before marking an account as checked. Gmail handles sign-in; LinkRouter never sends email.", systemImage: "info.circle").font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(3)
            destinationGroup("MAIL APPS & UTILITIES", values: model.allDestinations.filter { $0.kind == .mailApp || $0.kind == .copy })
            ForEach(model.discoveryNotices, id: \.self) { Text($0).font(.system(size: 11)).foregroundStyle(Palette.muted) }
        }.sheet(isPresented: $showAccount) { AddAccountView().environmentObject(model) }
    }
    func destinationGroup(_ title: String, values: [Destination]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: title)
            Card(padding: 18) {
                VStack(spacing: 15) {
                    ForEach(values) { d in
                        HStack { DestinationRow(destination: d); Toggle("Show in picker", isOn: Binding(get: { !model.preferences.hiddenDestinationIDs.contains(d.id) }, set: { enabled in model.change { if enabled { $0.preferences.hiddenDestinationIDs.remove(d.id) } else { $0.preferences.hiddenDestinationIDs.insert(d.id) } } })).labelsHidden().toggleStyle(.switch).controlSize(.mini).help("Show \(d.name) in the picker").disabled(d.kind == .copy) }
                        if d.id != values.last?.id { Divider() }
                    }
                }
            }
        }
    }
}

struct AddAccountView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var profileID = ""
    var profiles: [Destination] { model.allDestinations.filter { $0.kind == .browser && $0.bundleID == "com.google.Chrome" } }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeading(title: "An account, in its own profile", detail: "Choose the Chrome profile where you use this Google account.")
            TextField("you@company.com", text: $email).textFieldStyle(.roundedBorder)
            Picker("Chrome profile", selection: $profileID) { ForEach(profiles) { Text($0.detail).tag($0.id) } }
            Text("This adds a routing destination. It does not sign in to Google or verify the active Gmail account.").font(.system(size: 11)).foregroundStyle(Palette.muted)
            HStack { Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction); Spacer(); Button("Add account") { if let p = profiles.first(where: { $0.id == profileID }) { model.addAccount(email: email, profile: p); dismiss() } }.buttonStyle(PrimaryButtonStyle()).disabled(!valid) }
        }.padding(28).frame(width: 450).foregroundStyle(Palette.ink).background(Palette.canvas).onAppear { profileID = profiles.first?.id ?? "" }
    }
    var valid: Bool { let v = email.trimmingCharacters(in: .whitespacesAndNewlines); return v.contains("@") && !v.contains(where: { $0.isWhitespace }) && !v.contains(",") && !profileID.isEmpty }
}

struct RulesView: View {
    @EnvironmentObject var model: AppModel
    @State private var search = ""
    @State private var deleteRule: RoutingRule?
    var filtered: [RoutingRule] { model.rules.filter { search.isEmpty || $0.pattern.localizedCaseInsensitiveContains(search) || $0.scope.title.localizedCaseInsensitiveContains(search) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack { SectionHeading(title: "Teach it once", detail: "Remember a choice in the picker, or add a rule here."); Spacer(); Button { model.editingRule = nil; model.showRuleEditor = true } label: { Label("New rule", systemImage: "plus") }.buttonStyle(PrimaryButtonStyle()) }
            HStack { Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted); TextField("Find a website, email domain, or app…", text: $search).textFieldStyle(.plain) }.padding(11).background(Palette.card, in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line))
            if filtered.isEmpty {
                Card { VStack(spacing: 12) { Image(systemName: "arrow.triangle.branch").font(.system(size: 28)).foregroundStyle(Palette.green); Text(search.isEmpty ? "Your shortcuts start here" : "No matching rules").font(.headline); Text("Choose Remember in the picker to make your next link effortless.").font(.system(size: 12)).foregroundStyle(Palette.muted) }.frame(maxWidth: .infinity).padding(.vertical, 38) }
            } else {
                Card(padding: 0) {
                    VStack(spacing: 0) {
                        HStack { Eyebrow(text: "When a link matches"); Spacer(); Eyebrow(text: "Open in") }.padding(.horizontal, 20).padding(.vertical, 15).background(Palette.canvas.opacity(0.7))
                        ForEach(filtered) { rule in ruleRow(rule); if rule.id != filtered.last?.id { Divider().padding(.horizontal, 19) } }
                    }
                }.clipShape(RoundedRectangle(cornerRadius: 14))
            }
            Card {
                HStack(alignment: .top, spacing: 13) {
                    Image(systemName: "lightbulb").font(.system(size: 20)).foregroundStyle(Palette.green)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("You’re always in control").font(.system(size: 12, weight: .semibold))
                        Text("Hold ⌘ while choosing to remember. Hold ⌥ when opening a link to bring the picker back.").font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(4)
                        Text("Exact domain → wildcard website → source app → default. Order resolves ties within the same scope. Wildcards match subdomains only.").font(.system(size: 10)).foregroundStyle(Palette.muted).lineSpacing(3)
                    }
                }
            }
            Text("Source-app rules apply only when the URL event includes a trustworthy sender. Frontmost-app guessing is never used.").font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(3)
        }.alert("Delete this rule?", isPresented: Binding(get: { deleteRule != nil }, set: { if !$0 { deleteRule = nil } })) { Button("Cancel", role: .cancel) {}; Button("Delete rule", role: .destructive) { if let rule = deleteRule { model.change { $0.rules.removeAll { $0.id == rule.id } } }; deleteRule = nil } } message: { Text(deleteRule?.pattern ?? "") }
    }
    func ruleRow(_ rule: RoutingRule) -> some View {
        let destination = model.allDestinations.first { $0.id == rule.destinationID }
        return HStack(spacing: 12) {
            Toggle("Enable rule for \(rule.pattern)", isOn: Binding(get: { model.rules.first { $0.id == rule.id }?.enabled ?? false }, set: { value in model.change { config in if let i = config.rules.firstIndex(where: { $0.id == rule.id }) { config.rules[i].enabled = value } } })).labelsHidden().toggleStyle(.switch).controlSize(.mini)
            VStack(alignment: .leading, spacing: 5) { Text(rule.scope == .emailDomain ? "@\(rule.pattern)" : rule.pattern).font(.system(size: 12, weight: .medium)); Text(rule.scope.title).font(.system(size: 10)).foregroundStyle(Palette.muted) }.frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "arrow.right").font(.system(size: 11)).foregroundStyle(Palette.muted)
            HStack(spacing: 8) { if let destination { DestinationIcon(destination: destination, size: 22) }; VStack(alignment: .leading, spacing: 4) { Text(destination?.name ?? "Unavailable destination").font(.system(size: 11, weight: .medium)); Text(destination?.detail ?? "Edit to choose another").font(.system(size: 9)).foregroundStyle(Palette.muted) } }.frame(width: 185, alignment: .leading)
            Menu {
                Button("Edit rule…") { model.editingRule = rule; model.showRuleEditor = true }
                Button("Move up") { move(rule, by: -1) }.disabled(model.rules.first?.id == rule.id)
                Button("Move down") { move(rule, by: 1) }.disabled(model.rules.last?.id == rule.id)
                Divider(); Button("Delete rule…", role: .destructive) { deleteRule = rule }
            } label: { Image(systemName: "ellipsis").frame(width: 18, height: 22) }.menuStyle(.borderlessButton).frame(width: 20)
        }.padding(.horizontal, 20).padding(.vertical, 18).opacity(rule.enabled ? 1 : 0.55)
    }
    func move(_ rule: RoutingRule, by delta: Int) { model.change { value in if let i = value.rules.firstIndex(where: { $0.id == rule.id }), value.rules.indices.contains(i + delta) { value.rules.swapAt(i, i + delta) } } }
}

struct RuleEditor: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    var rule: RoutingRule?
    @State private var scope: RuleScope = .website
    @State private var pattern = ""
    @State private var destinationID = ""
    var targets: [Destination] { model.destinations.filter { scope == .emailDomain ? $0.supportsEmail : scope == .website ? $0.supportsWeb : true } }
    var body: some View {
        VStack(alignment: .leading, spacing: 21) {
            SectionHeading(title: rule == nil ? "Make the next link effortless" : "Edit your rule", detail: "A small preference, remembered on this Mac.")
            Picker("Match", selection: $scope) { ForEach(RuleScope.allCases, id: \.self) { Text($0.title).tag($0) } }.pickerStyle(.segmented).labelsHidden()
            VStack(alignment: .leading, spacing: 8) { Text(scope == .sourceApp ? "Application bundle ID" : "Domain").font(.system(size: 12, weight: .medium)); TextField(scope == .sourceApp ? "com.tinyspeck.slackmacgap" : scope == .emailDomain ? "northwind.co" : "figma.com or *.figma.com", text: $pattern).textFieldStyle(.roundedBorder) }
            Picker("Open in", selection: $destinationID) { Text("Choose a destination").tag(""); ForEach(targets) { Text("\($0.name) · \($0.detail)").tag($0.id) } }
            if scope == .sourceApp { Text("Applied only when macOS supplies sender metadata. Some apps and intermediary services do not identify the original app.").font(.system(size: 11)).foregroundStyle(Palette.muted) }
            HStack { Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction); Spacer(); Button("Save rule") { model.saveRule(.init(id: rule?.id ?? UUID(), scope: scope, pattern: pattern.trimmingCharacters(in: .whitespacesAndNewlines), destinationID: destinationID, enabled: rule?.enabled ?? true)); dismiss() }.buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction).disabled(!RoutingRule.validPattern(pattern, scope: scope) || !targets.contains { $0.id == destinationID }) }
        }.padding(30).frame(width: 480).foregroundStyle(Palette.ink).background(Palette.canvas).onAppear { if let rule { scope = rule.scope; pattern = rule.pattern; destinationID = rule.destinationID } }.onChange(of: scope) { _, _ in if !targets.contains(where: { $0.id == destinationID }) { destinationID = "" } }
    }
}

struct PrivacyView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "hand.raised.fingers.spread.fill").font(.system(size: 35)).foregroundStyle(Palette.green)
                Text("A private little handoff.").font(.system(size: 29, weight: .medium, design: .rounded))
                Text("LinkRouter does its work on your Mac. Your links don’t take a trip through our servers to get where they’re going.").font(.system(size: 13)).foregroundStyle(Palette.muted).lineSpacing(5).frame(maxWidth: 540, alignment: .leading)
            }.padding(28).frame(maxWidth: .infinity, alignment: .leading).background(Palette.pale, in: RoundedRectangle(cornerRadius: 15))
            privacyRow("No browsing history", detail: "Incoming URLs live in memory only while they’re being handled. Closing the picker clears that request.", icon: "clock.badge.checkmark")
            privacyRow("No network requests", detail: "Cleanup uses known redirect formats. Opaque newsletter redirects stay intact; LinkRouter never fetches a page to resolve them.", icon: "network.slash")
            privacyRow("Only the settings you choose", detail: "Rules, preferences, and manually added accounts are stored in a local SQLite database in Application Support/LinkRouter. Demo changes are temporary.", icon: "internaldrive")
            privacyRow("No cookies or credentials", detail: "Browser discovery reads local profile names and account email hints. It never reads your cookies, passwords, tokens, or messages. Signing in and sending happen in Gmail.", icon: "key.slash")
            Text("LinkRouter uses no analytics, advertising SDKs, or third-party dependencies. Your chosen browser or mail app will make its normal network connections after you open a link.").font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(4)
        }
    }
    func privacyRow(_ title: String, detail: String, icon: String) -> some View { Card { HStack(alignment: .top, spacing: 16) { Image(systemName: icon).font(.system(size: 21)).foregroundStyle(Palette.green).frame(width: 30); VStack(alignment: .leading, spacing: 7) { Text(title).font(.system(size: 13, weight: .semibold)); Text(detail).font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(4) } } } }
}
