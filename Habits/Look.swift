import HabitsKit
import SwiftUI

extension Color {
    init(hex: String) {
        let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x8fa2ff
        self.init(
            red: Double(value >> 16 & 0xff) / 255,
            green: Double(value >> 8 & 0xff) / 255,
            blue: Double(value & 0xff) / 255)
    }

    var hex: String {
        let rgb = UIColor(self).cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)?.components ?? [0, 0, 0]
        return String(format: "#%02x%02x%02x", Int(rgb[0] * 255), Int(rgb[1] * 255), Int(rgb[2] * 255))
    }
}

struct Backdrop: View {
    @Environment(Store.self) var store

    var body: some View {
        let base = Color(hex: "#07070f")
        let accent = Color(hex: store.color)
        RadialGradient(
            colors: [base.mix(with: accent, by: 0.35), base.mix(with: accent, by: 0.12), Color(hex: "#06060a")],
            center: UnitPoint(x: 0.2, y: 0), startRadius: 0, endRadius: 760
        )
        .ignoresSafeArea()
    }
}

struct Rows: View {
    @Environment(Store.self) var store

    var body: some View {
        Color(hex: store.color).opacity(0.12).background(.white.opacity(0.04))
    }
}
