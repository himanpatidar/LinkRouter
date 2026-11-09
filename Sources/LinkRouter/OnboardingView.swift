import SwiftUI
import LinkRouterCore

struct OnboardingView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    @State private var step = 0
    @State private var defaultID = ""
    let titles = ["Every link has a place.", "Let links come to you.", "Meet your destinations.", "Choose your starting point.", "You’re ready to route."]
    let subtitles = ["A work profile for work. A personal one for everything else. One small picker to keep it all straight.", "Make LinkRouter the handler for web and email links. macOS may ask you to confirm the change.", "Discover browser profiles and Google account hints from local files. Nothing leaves this Mac.", "Choose a fallback for links without a rule. You can always hold Option to bring back the picker.", "Try a link, choose a destination, and make yourself at home. LinkRouter will be waiting in your menu bar."]
    var body: some View {
        VStack(spacing: 0) {
            HStack { BrandMark(size: 30); Text("LinkRouter").font(.system(size: 16, weight: .semibold, design: .rounded)); Spacer(); Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 11)).foregroundStyle(Palette.muted) }.buttonStyle(.plain).accessibilityLabel("Close setup") }.padding(27)
            VStack(spacing: 18) {
                ZStack { Circle().fill(Palette.pale).frame(width: 84, height: 84); Image(systemName: ["arrow.triangle.branch", "link.badge.plus", "globe", "cursorarrow.click.2", "checkmark"][step]).font(.system(size: 31, weight: .light)).foregroundStyle(Palette.green) }.padding(.bottom, 4)
                Text(titles[step]).font(.system(size: 29, weight: .medium, design: .rounded)).tracking(-0.5)
                Text(subtitles[step]).font(.system(size: 13)).foregroundStyle(Palette.muted).multilineTextAlignment(.center).lineSpacing(4).frame(maxWidth: 395)
                Group {
                    switch step {
                    case 0:
                        HStack(spacing: 20) { Label("Local by design", systemImage: "lock.shield"); Label("Made for macOS", systemImage: "command") }.font(.system(size: 10)).foregroundStyle(Palette.green).padding(.top, 14)
                    case 1:
                        VStack(spacing: 11) {
                            handler("Web links", scheme: "https", email: false)
                            handler("Email links", scheme: "mailto", email: true)
                            Text("You can skip this and change it later in General.").font(.system(size: 10)).foregroundStyle(Palette.muted)
                        }.padding(.top, 5)
                    case 2:
                        VStack(spacing: 12) {
                            Button(model.didDiscover ? "Scan again" : "Discover browsers") { model.discover() }.buttonStyle(QuietButtonStyle())
                            if model.didDiscover { Text("\(model.discovered.filter { $0.kind == .browser }.count) browser destinations · \(model.discovered.filter { $0.kind == .gmail }.count) Google account candidates").font(.system(size: 12)).foregroundStyle(Palette.green); Text("Account candidates need your check in Destinations.").font(.system(size: 10)).foregroundStyle(Palette.muted) }
                        }.padding(.top, 10)
                    case 3:
                        Picker("Unmatched links", selection: $defaultID) { Text("Ask every time (recommended)").tag(""); ForEach(model.discovered.filter(\.supportsWeb)) { Text("\($0.name) · \($0.detail)").tag($0.id) } }.labelsHidden().frame(width: 325).padding(.top, 15)
                    default:
                        Button { model.receive(Samples.safeLink, demo: false, forcePicker: true) } label: { Label("Open a test link", systemImage: "arrow.up.right") }.buttonStyle(QuietButtonStyle()).padding(.top, 14)
                    }
                }.frame(height: 140, alignment: .top)
            }.frame(maxWidth: .infinity).padding(.horizontal, 32)
            Spacer(minLength: 0)
            HStack {
                if step > 0 { Button("Back") { step -= 1 }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Palette.muted) } else { Button("Explore the demo") { model.isDemo = true; dismiss() }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Palette.muted) }
                Spacer()
                HStack(spacing: 6) { ForEach(0..<5) { index in Capsule().fill(index == step ? Palette.green : Palette.line).frame(width: index == step ? 19 : 5, height: 5) } }
                Spacer()
                Button(step == 4 ? "All set" : "Continue") {
                    if step == 0 { model.isDemo = false }
                    if step == 3 { model.config.preferences.defaultWebID = defaultID.isEmpty ? nil : defaultID; model.save() }
                    if step == 4 { model.config.preferences.completedOnboarding = true; model.isDemo = false; model.save(); dismiss() } else { step += 1 }
                }.buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction)
            }.padding(28)
        }.frame(width: 550, height: 560).background(Palette.canvas).foregroundStyle(Palette.ink).tint(Palette.green)
        .onAppear { defaultID = model.config.preferences.defaultWebID ?? "" }
    }
    func handler(_ name: String, scheme: String, email: Bool) -> some View {
        HStack { Label(name, systemImage: email ? "envelope" : "globe").font(.system(size: 12)); Spacer(); if model.handlerStatus[scheme] == true { Label("Connected", systemImage: "checkmark.circle.fill").font(.system(size: 11)).foregroundStyle(Palette.green) } else { Button("Make default…") { model.makeDefault(email: email) }.buttonStyle(QuietButtonStyle()) } }.padding(12).background(Palette.card, in: RoundedRectangle(cornerRadius: 9)).frame(width: 375)
    }
}
