import SwiftUI
import LinkRouterCore

extension Notification.Name { static let pickerKey = Notification.Name("LinkRouter.PickerKey") }
struct PickerKeystroke { var key: String; var flags: NSEvent.ModifierFlags }

struct PickerView: View {
    @EnvironmentObject var model: AppModel
    @State private var selected = 0
    @State private var remember = false
    @State private var scope: RuleScope = .website
    @State private var diagnostics = false
    @State private var confirmation: Destination?
    var body: some View {
        VStack(spacing: 0) {
            if let link = model.pending {
                header(link)
                Divider().overlay(Palette.line)
                if let destination = confirmation { confirmAccount(destination) }
                else {
                    ScrollView {
                        VStack(spacing: 3) {
                            ForEach(Array(model.pickerDestinations.enumerated()), id: \.element.id) { index, destination in
                                Button { selected = index; pick(destination, command: NSEvent.modifierFlags.contains(.command)) } label: {
                                    HStack(spacing: 11) {
                                        DestinationIcon(destination: destination, size: 29)
                                        VStack(alignment: .leading, spacing: 4) { Text(link.isMail && destination.kind == .copy ? "Copy email address" : destination.name).font(.system(size: 12, weight: .medium)).lineLimit(1); Text(destination.detail).font(.system(size: 10)).foregroundStyle(Palette.muted).lineLimit(1) }
                                        Spacer()
                                        if index < 5 { Text("\(index + 1)").font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(Palette.muted).frame(width: 23, height: 22).background(Palette.card, in: RoundedRectangle(cornerRadius: 5)).overlay(RoundedRectangle(cornerRadius: 5).stroke(Palette.line)) }
                                    }.padding(.horizontal, 11).padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading).background(selected == index ? Palette.pale : Color.clear, in: RoundedRectangle(cornerRadius: 8)).contentShape(Rectangle())
                                }.buttonStyle(.plain).disabled(model.isLaunching).onHover { if $0 { selected = index } }
                            }
                        }.padding(8)
                    }.frame(height: min(295, CGFloat(model.pickerDestinations.count * 58 + 16)))
                    if let error = model.pickerError { Label(error, systemImage: "exclamationmark.triangle").font(.system(size: 10)).foregroundStyle(.orange).lineSpacing(3).padding(.horizontal, 16).padding(.bottom, 10) }
                    Divider()
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Toggle("Remember", isOn: $remember).toggleStyle(.checkbox).font(.system(size: 11))
                            Spacer()
                            if remember {
                                Picker("Scope", selection: $scope) {
                                    if !link.isMail { Text("This website").tag(RuleScope.website) }
                                    if link.isMail && (try? Mailto(url: link.result.url))?.recipientDomain != nil { Text("This email domain").tag(RuleScope.emailDomain) }
                                    if link.sourceBundleID != nil { Text("This app").tag(RuleScope.sourceApp) }
                                }.labelsHidden().frame(width: 153).controlSize(.small)
                            } else { Text("or hold ⌘ while choosing").font(.system(size: 9)).foregroundStyle(Palette.muted) }
                        }.disabled(!canRemember(link))
                        HStack { Button { diagnostics.toggle() } label: { Label(diagnostics ? "Hide details" : "Link details", systemImage: "info.circle") }.buttonStyle(.plain); Spacer(); Text("C copy · esc close") }.font(.system(size: 9)).foregroundStyle(Palette.muted)
                        if diagnostics { VStack(alignment: .leading, spacing: 8) { diagnostic("ORIGINAL", link.result.original.absoluteString); diagnostic("OPENING", link.result.url.absoluteString); if let source = link.sourceBundleID { diagnostic("URL EVENT SENDER", source) }; if !link.result.removedParameters.isEmpty { diagnostic("REMOVED", link.result.removedParameters.joined(separator: ", ")) } }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Palette.canvas, in: RoundedRectangle(cornerRadius: 7)) }
                    }.padding(15)
                }
            }
        }.frame(width: 390).background(.regularMaterial).foregroundStyle(Palette.ink).tint(Palette.green)
        .onAppear { if model.pending?.isMail == true { scope = .emailDomain } }
        .onChange(of: model.pending?.id) { _, _ in selected = 0; remember = false; diagnostics = false; confirmation = nil; scope = model.pending?.isMail == true ? .emailDomain : .website }
        .onReceive(NotificationCenter.default.publisher(for: .pickerKey)) { notification in if let event = notification.object as? PickerKeystroke { handle(event) } }
    }
    func header(_ link: PendingLink) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Eyebrow(text: link.isDemo ? "Choose a destination · demo" : "Choose a destination"); Spacer(); Button { model.dismissPicker() } label: { Image(systemName: "xmark").font(.system(size: 9)).foregroundStyle(Palette.muted) }.buttonStyle(.plain).accessibilityLabel("Close picker") }
            HStack(spacing: 9) { Image(systemName: link.isMail ? "envelope" : "link").font(.system(size: 14)).foregroundStyle(Palette.green); Text(link.title).font(.system(size: 15, weight: .semibold)).lineLimit(1).truncationMode(.middle) }
            if link.isMail { Text("Choose your sender. Check the account in Gmail before sending.").font(.system(size: 10)).foregroundStyle(Palette.muted).lineSpacing(3) }
            else { Label(link.result.summary, systemImage: "checkmark.shield").font(.system(size: 9)).foregroundStyle(Palette.green) }
        }.padding(17)
    }
    func diagnostic(_ title: String, _ value: String) -> some View { VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 8, weight: .semibold)).foregroundStyle(Palette.muted); Text(value).font(.system(size: 9, design: .monospaced)).textSelection(.enabled).lineLimit(4) } }
    func canRemember(_ link: PendingLink) -> Bool { !link.isMail || (try? Mailto(url: link.result.url))?.recipientDomain != nil || link.sourceBundleID != nil }
    func pick(_ destination: Destination, command: Bool = false) {
        guard let link = model.pending else { return }
        if command && canRemember(link) { remember = true }
        let prefs = link.isDemo ? model.demoConfig.preferences : model.config.preferences
        if destination.kind == .gmail && !prefs.confirmedAccountIDs.contains(destination.id) { confirmation = destination; return }
        Task { if destination.kind == .copy && link.isMail && !remember { model.copyPending(addressOnly: true) } else { await model.choose(destination, remember: remember && canRemember(link), scope: scope) } }
    }
    func confirmAccount(_ destination: Destination) -> some View {
        VStack(alignment: .leading, spacing: 17) {
            DestinationRow(destination: destination)
            Text("Check this account in Gmail").font(.system(size: 14, weight: .semibold))
            Text("This address came from local profile metadata or was added manually. It may no longer be signed in. LinkRouter requests this account, but Gmail controls sign-in and the final sender.").font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(4)
            Text("After checking, you can mark the account as confirmed in Destinations to enable automatic rules.").font(.system(size: 10)).foregroundStyle(Palette.muted).lineSpacing(3)
            HStack { Button("Back") { confirmation = nil }.buttonStyle(QuietButtonStyle()); Spacer(); Button("Open Gmail compose") { Task { await model.choose(destination, remember: remember, scope: scope); if model.pending != nil { confirmation = nil } } }.buttonStyle(PrimaryButtonStyle()).disabled(model.isLaunching) }
        }.padding(20)
    }
    func handle(_ event: PickerKeystroke) {
        if event.key == "\u{1b}" { if confirmation != nil { confirmation = nil } else { model.dismissPicker() }; return }
        guard confirmation == nil, !model.isLaunching else { return }
        if event.key.lowercased() == "c" { model.copyPending(); return }
        if event.key == "↓" { selected = min(selected + 1, model.pickerDestinations.count - 1) }
        else if event.key == "↑" { selected = max(selected - 1, 0) }
        else if event.key == "\r", model.pickerDestinations.indices.contains(selected) { pick(model.pickerDestinations[selected], command: event.flags.contains(.command)) }
        else if let number = Int(event.key), (1...5).contains(number), model.pickerDestinations.indices.contains(number - 1) { selected = number - 1; pick(model.pickerDestinations[selected], command: event.flags.contains(.command)) }
    }
}
