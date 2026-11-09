import SwiftUI
import AppKit
import LinkRouterCore

enum Palette {
    static let green = adaptive(0x28634D, dark: 0x8AC9A9)
    static let ink = adaptive(0x25352E, dark: 0xE4EBE5)
    static let muted = adaptive(0x788078, dark: 0xA3AEA5)
    static let canvas = adaptive(0xF8F9F6, dark: 0x1C211E)
    static let sidebar = adaptive(0xF0F2ED, dark: 0x171C19)
    static let card = adaptive(0xFFFFFF, dark: 0x252B27)
    static let pale = adaptive(0xE9F0E8, dark: 0x2B3A30)
    static let line = adaptive(0xE3E7DF, dark: 0x38413A)
    static func adaptive(_ light: UInt32, dark: UInt32) -> Color {
        func color(_ hex: UInt32) -> NSColor { NSColor(srgbRed: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, alpha: 1) }
        return Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? color(dark) : color(light) })
    }
}

struct BrandMark: View {
    var size: CGFloat = 36
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28).fill(Palette.green)
            Image(systemName: "arrow.triangle.branch").font(.system(size: size * 0.49, weight: .medium)).foregroundStyle(Palette.canvas).rotationEffect(.degrees(90))
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct DestinationIcon: View {
    var destination: Destination
    var size: CGFloat = 34
    var body: some View {
        Group {
            if destination.kind == .copy { icon("doc.on.doc", color: Palette.muted) }
            else if destination.kind == .gmail { icon("envelope.fill", color: .red.opacity(0.8)) }
            else if destination.bundleID == "com.google.Chrome" {
                ZStack {
                    Canvas { context, s in
                        let center = CGPoint(x: s.width / 2, y: s.height / 2)
                        for (start, color) in [(Double(-90), Color(red: 0.91, green: 0.29, blue: 0.24)), (Double(30), Color(red: 0.96, green: 0.76, blue: 0.25)), (Double(150), Color(red: 0.24, green: 0.65, blue: 0.37))] {
                            var path = Path(); path.move(to: center); path.addArc(center: center, radius: s.width / 2, startAngle: .degrees(start), endAngle: .degrees(start + 120), clockwise: false); path.closeSubpath(); context.fill(path, with: .color(color))
                        }
                    }.clipShape(Circle())
                    Circle().fill(.white).frame(width: size * 0.47, height: size * 0.47)
                    Circle().fill(Color(red: 0.27, green: 0.57, blue: 0.88)).frame(width: size * 0.36, height: size * 0.36)
                }
            } else if destination.bundleID == "com.apple.Safari" { icon("safari.fill", color: .blue) }
            else if destination.kind == .mailApp { icon("envelope.fill", color: .blue) }
            else { icon("globe", color: Palette.green) }
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
    func icon(_ symbol: String, color: Color) -> some View { Image(systemName: symbol).font(.system(size: size * 0.73, weight: .regular)).foregroundStyle(color) }
}

struct Card<Content: View>: View {
    var padding: CGFloat = 22
    @ViewBuilder var content: Content
    var body: some View { content.padding(padding).frame(maxWidth: .infinity, alignment: .leading).background(Palette.card, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1)) }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label.font(.system(size: 13, weight: .semibold)).padding(.horizontal, 17).padding(.vertical, 11).foregroundStyle(Palette.canvas).background(Palette.green.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 8))
    }
}
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 8).background(configuration.isPressed ? Palette.pale : Palette.card, in: RoundedRectangle(cornerRadius: 7)).overlay(RoundedRectangle(cornerRadius: 7).stroke(Palette.line)).foregroundStyle(Palette.ink)
    }
}
struct Eyebrow: View {
    var text: String
    var body: some View { Text(text.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(1.7).foregroundStyle(Palette.muted) }
}
struct SectionHeading: View {
    var title: String; var detail: String?
    var body: some View { VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(size: 18, weight: .semibold)); if let detail { Text(detail).font(.system(size: 12)).foregroundStyle(Palette.muted) } } }
}

struct DestinationRow: View {
    var destination: Destination
    var body: some View { HStack(spacing: 12) { DestinationIcon(destination: destination); VStack(alignment: .leading, spacing: 4) { Text(destination.name).font(.system(size: 13, weight: .medium)); Text(destination.detail).font(.system(size: 11)).foregroundStyle(Palette.muted) }; Spacer() } }
}
