import SwiftUI
import LinkRouterCore

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 206)
            Rectangle().fill(Palette.line).frame(width: 1)
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if let error = model.storageError { Label(error, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.orange).padding().background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10)) }
                        switch model.page {
                        case .overview: OverviewView()
                        case .general: GeneralView()
                        case .destinations: DestinationsView()
                        case .rules: RulesView()
                        case .privacy: PrivacyView()
                        }
                    }.frame(maxWidth: 960).padding(.horizontal, 34).padding(.top, 8).padding(.bottom, 32).frame(maxWidth: .infinity)
                }
            }.background(Palette.canvas)
        }
        .foregroundStyle(Palette.ink).tint(Palette.green)
        .frame(minWidth: 930, minHeight: 680)
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                Label(toast, systemImage: "checkmark.circle.fill").font(.system(size: 12, weight: .medium)).padding(.horizontal, 18).padding(.vertical, 12).background(.regularMaterial, in: Capsule()).shadow(color: .black.opacity(0.1), radius: 12, y: 4).padding(.bottom, 20).transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.toast)
        .sheet(isPresented: $model.showOnboarding) { OnboardingView().environmentObject(model) }
        .sheet(isPresented: $model.showRuleEditor) { RuleEditor(rule: model.editingRule).environmentObject(model) }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.refreshHandlers() }
    }
    var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) { BrandMark(size: 31); Text("LinkRouter").font(.system(size: 18, weight: .semibold, design: .rounded)) }.padding(.top, 47).padding(.bottom, 39).padding(.horizontal, 23)
            Eyebrow(text: "Workspace").padding(.leading, 25).padding(.bottom, 13)
            ForEach(SettingsPage.allCases) { page in
                Button { model.page = page } label: {
                    HStack(spacing: 11) { Image(systemName: page.symbol).font(.system(size: 14)).frame(width: 19); Text(page.rawValue).font(.system(size: 13, weight: model.page == page ? .semibold : .regular)); Spacer(); if page == .rules { Text("\(model.rules.count)").font(.system(size: 10, weight: .medium)).padding(.horizontal, 6).padding(.vertical, 2).background(Palette.card.opacity(0.75), in: Capsule()) } }.padding(.horizontal, 13).padding(.vertical, 11).foregroundStyle(model.page == page ? Palette.green : Palette.ink).background(model.page == page ? Palette.pale : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain).padding(.horizontal, 12).padding(.bottom, 4)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 7) { Circle().fill(Palette.green).frame(width: 6, height: 6); Text(model.isDemo ? "Sample workspace" : "Ready when you are").font(.system(size: 11, weight: .medium)) }
                Text(model.isDemo ? "Explore freely. Demo links stay here." : "Quietly at home in your menu bar.").font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(4)
                Button(model.isDemo ? "Set up on this Mac  ↗" : "Open setup  ↗") { model.showOnboarding = true }.buttonStyle(.plain).font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.green)
            }.padding(15).frame(maxWidth: .infinity, alignment: .leading).background(Palette.card.opacity(0.65), in: RoundedRectangle(cornerRadius: 10)).padding(15)
            HStack { Text("MADE FOR YOUR MAC").tracking(1.2); Spacer(); Text("1.0") }.font(.system(size: 8, weight: .medium)).foregroundStyle(Palette.muted).padding(.horizontal, 22).padding(.bottom, 20)
        }.background(Palette.sidebar)
    }
    var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) { Text(model.page.rawValue).font(.system(size: 27, weight: .semibold)); Text(model.page.subtitle).font(.system(size: 12)).foregroundStyle(Palette.muted) }
            Spacer()
            if model.isDemo {
                if model.config.preferences.completedOnboarding { Button("Exit demo") { model.useRealWorkspace() }.buttonStyle(QuietButtonStyle()) }
                Label("Demo mode", systemImage: "sparkle").font(.system(size: 10, weight: .medium)).padding(.horizontal, 11).padding(.vertical, 7).background(Palette.pale, in: Capsule()).foregroundStyle(Palette.green)
            } else {
                Button { model.isDemo = true } label: { Label("Try demo", systemImage: "play.circle") }.buttonStyle(QuietButtonStyle())
            }
        }.padding(.horizontal, 34).padding(.top, 43).padding(.bottom, 26)
    }
}

struct OverviewView: View {
    @EnvironmentObject var model: AppModel
    @State private var selected = 0
    @State private var customLink = ""
    @State private var showCustom = false
    var result: NormalizationResult { URLNormalizer().normalize(URL(string: Samples.links[selected].url)!) }
    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            hero
            HStack(spacing: 13) {
                metric("globe", value: "\(model.destinations.filter { $0.kind == .browser }.count)", title: "Browser destinations") { model.page = .destinations }
                metric("arrow.triangle.branch", value: "\(model.rules.filter(\.enabled).count)", title: "Rules remembered") { model.page = .rules }
                metric("sparkles", value: model.preferences.stripTracking ? "On" : "Off", title: "Link cleanup") { model.page = .general }
            }
            HStack { SectionHeading(title: "Give it a little test", detail: "Pick a link. See where it takes you."); Spacer(); Button { showCustom.toggle() } label: { Label("Your own link", systemImage: "link") }.buttonStyle(QuietButtonStyle()) }
            if showCustom {
                HStack { TextField("Paste a web or mailto link…", text: $customLink).textFieldStyle(.roundedBorder).onSubmit { model.test(customLink) }; Button("Open picker") { model.test(customLink) }.buttonStyle(QuietButtonStyle()).disabled(customLink.isEmpty) }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(Array(Samples.links.enumerated()), id: \.offset) { index, link in
                    Button { selected = index; model.test(link.url) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: link.icon).font(.system(size: 17)).foregroundStyle(Palette.green).frame(width: 37, height: 37).background(Palette.pale.opacity(0.7), in: RoundedRectangle(cornerRadius: 9))
                            VStack(alignment: .leading, spacing: 5) { Text(link.name).font(.system(size: 12, weight: .semibold)); Text(link.subtitle).font(.system(size: 10)).foregroundStyle(Palette.muted) }
                            Spacer(minLength: 0); Image(systemName: "arrow.up.right").font(.system(size: 10)).foregroundStyle(Palette.muted)
                        }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Palette.card, in: RoundedRectangle(cornerRadius: 11)).overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.line))
                    }.buttonStyle(.plain)
                }
            }
            cleanPreview
            HStack(spacing: 6) { Image(systemName: "lock.shield"); Text("Processed on your Mac. No servers. No browsing history.") }.font(.system(size: 10)).foregroundStyle(Palette.muted).frame(maxWidth: .infinity).padding(.top, 2)
        }
    }
    var hero: some View {
        HStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) { Image(systemName: "arrow.up.right"); Text("A SMALL UTILITY. A SMOOTHER DAY.").tracking(1.3) }.font(.system(size: 8, weight: .semibold)).foregroundStyle(Palette.green)
                Text("Right link.\nRight place.").font(.system(size: 34, weight: .medium, design: .rounded)).tracking(-1.1).lineSpacing(0)
                Text("Work in one profile. Life in another.\nLet your links find their way.").font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(4)
                Button { model.test(Samples.safeLink) } label: { HStack(spacing: 14) { Text("Try the picker"); Image(systemName: "arrow.right") } }.buttonStyle(PrimaryButtonStyle()).padding(.top, 3)
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 0) {
                HStack(spacing: 6) { Image(systemName: "link").foregroundStyle(Palette.green); Text("northwind.co/pricing").foregroundStyle(Palette.ink); Spacer(); Image(systemName: "checkmark.shield.fill").foregroundStyle(Palette.green) }.font(.system(size: 10)).padding(12).background(Palette.card.opacity(0.6), in: RoundedRectangle(cornerRadius: 8)).padding(.bottom, 12)
                ForEach(Array(Samples.destinations.prefix(3).enumerated()), id: \.offset) { index, d in
                    HStack(spacing: 10) { DestinationIcon(destination: d, size: 25); VStack(alignment: .leading, spacing: 3) { Text(d.name).font(.system(size: 11, weight: .medium)); Text(d.detail).font(.system(size: 9)).foregroundStyle(Palette.muted) }; Spacer(); Text("\(index + 1)").font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(Palette.muted).frame(width: 21, height: 21).background(Palette.canvas, in: RoundedRectangle(cornerRadius: 4)) }.padding(10).background(index == 0 ? Palette.card : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                }
                HStack { Text("CHOOSE YOUR DESTINATION").tracking(1); Spacer(); Text("esc to close") }.font(.system(size: 7, weight: .medium)).foregroundStyle(Palette.muted).padding(.top, 14).padding(.horizontal, 3)
            }.padding(13).frame(width: 267).background(Palette.canvas.opacity(0.85), in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.card.opacity(0.8))).rotationEffect(.degrees(-2)).shadow(color: Palette.green.opacity(0.08), radius: 15, x: 0, y: 10).accessibilityLabel("Picker preview with Chrome work, Chrome personal, and Safari destinations")
        }.padding(27).frame(maxWidth: .infinity, alignment: .leading).background(LinearGradient(colors: [Palette.pale, Palette.pale.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.green.opacity(0.07)))
    }
    func metric(_ symbol: String, value: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { HStack(spacing: 12) { Image(systemName: symbol).font(.system(size: 16)).foregroundStyle(Palette.green); VStack(alignment: .leading, spacing: 3) { Text(value).font(.system(size: 19, weight: .semibold)); Text(title).font(.system(size: 10)).foregroundStyle(Palette.muted) }; Spacer() }.padding(17).frame(maxWidth: .infinity).background(Palette.card, in: RoundedRectangle(cornerRadius: 11)).overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.line)) }.buttonStyle(.plain)
    }
    var cleanPreview: some View {
        Card(padding: 18) {
            VStack(alignment: .leading, spacing: 13) {
                HStack { Label("A cleaner way there", systemImage: "sparkles").font(.system(size: 12, weight: .semibold)); Spacer(); Text("LOCAL PROCESSING").font(.system(size: 8, weight: .medium)).tracking(1).foregroundStyle(Palette.muted) }
                HStack(spacing: 11) {
                    Image(systemName: "arrow.turn.down.right").foregroundStyle(Palette.muted)
                    VStack(alignment: .leading, spacing: 5) { Text(selected == 3 ? "Email contents stay intact" : "What LinkRouter opens").font(.system(size: 10)).foregroundStyle(Palette.muted); Text(result.url.absoluteString).font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.green).lineLimit(1).truncationMode(.middle).textSelection(.enabled) }
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Palette.canvas, in: RoundedRectangle(cornerRadius: 7))
                HStack(spacing: 6) { Image(systemName: "checkmark.circle.fill"); Text(result.summary) }.font(.system(size: 10)).foregroundStyle(Palette.green)
            }
        }
    }
}

struct GeneralView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            SectionHeading(title: "At home on your Mac", detail: "Let LinkRouter handle the handoff.")
            Card {
                VStack(spacing: 20) {
                    settingRow("Default web handler", detail: model.handlerStatus["https"] == true && model.handlerStatus["http"] == true ? "LinkRouter handles web links" : "Receive links from apps across macOS", symbol: "globe") { Button("Make default…") { model.makeDefault(email: false) }.buttonStyle(QuietButtonStyle()).disabled(model.isDemo) }
                    Divider()
                    settingRow("Default email handler", detail: model.handlerStatus["mailto"] == true ? "LinkRouter handles email links" : "Choose an account for mailto links", symbol: "envelope") { Button("Make default…") { model.makeDefault(email: true) }.buttonStyle(QuietButtonStyle()).disabled(model.isDemo) }
                    Divider()
                    Toggle(isOn: Binding(get: { model.launchAtLogin }, set: { model.toggleLogin($0) })) { Label("Launch at login", systemImage: "power").font(.system(size: 13)) }.toggleStyle(.switch).disabled(model.isDemo)
                }
            }
            if model.isDemo { Text("System settings are available after you set up this Mac.").font(.system(size: 11)).foregroundStyle(Palette.muted) }
            SectionHeading(title: "When a link arrives", detail: "Rules take priority. Hold Option to ask again for a single link.")
            Card {
                VStack(spacing: 18) {
                    Picker("Unmatched web links", selection: Binding(get: { model.preferences.defaultWebID ?? "" }, set: { id in model.change { $0.preferences.defaultWebID = id.isEmpty ? nil : id } })) { Text("Ask every time").tag(""); ForEach(model.destinations.filter(\.supportsWeb)) { Text("\($0.name) · \($0.detail)").tag($0.id) } }.font(.system(size: 12))
                    Divider()
                    Picker("Unmatched email links", selection: Binding(get: { model.preferences.defaultMailID ?? "" }, set: { id in model.change { $0.preferences.defaultMailID = id.isEmpty ? nil : id } })) { Text("Ask every time").tag(""); ForEach(model.destinations.filter(\.supportsEmail)) { Text($0.name).tag($0.id) } }.font(.system(size: 12))
                }
            }
            SectionHeading(title: "Leave the tracking behind", detail: "Conservative cleanup, with the original link always available in the picker.")
            Card {
                VStack(spacing: 18) {
                    Toggle(isOn: Binding(get: { model.preferences.unwrapRedirects }, set: { v in model.change { $0.preferences.unwrapRedirects = v } })) { VStack(alignment: .leading, spacing: 5) { Text("Unwrap known redirects"); Text("Outlook Safe Links, Google, Slack, and supported newsletters.").font(.system(size: 11)).foregroundStyle(Palette.muted) } }.toggleStyle(.switch)
                    Divider()
                    Toggle(isOn: Binding(get: { model.preferences.stripTracking }, set: { v in model.change { $0.preferences.stripTracking = v } })) { VStack(alignment: .leading, spacing: 5) { Text("Remove tracking parameters"); Text("Keeps meaningful parameters, fragments, and signed URLs intact.").font(.system(size: 11)).foregroundStyle(Palette.muted) } }.toggleStyle(.switch)
                }.font(.system(size: 13))
            }
        }
    }
    func settingRow<Content: View>(_ title: String, detail: String, symbol: String, @ViewBuilder control: () -> Content) -> some View { HStack(spacing: 13) { Image(systemName: symbol).font(.system(size: 18)).foregroundStyle(Palette.green).frame(width: 23); VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 13, weight: .medium)); Text(detail).font(.system(size: 11)).foregroundStyle(Palette.muted) }; Spacer(); control() } }
}
