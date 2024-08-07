import SwiftUI

extension Color {
    static let appBackground = Color("2C2C2C")
    static let cardBackground = Color.white
    static let cardStroke = Color("E8E8E8")
    static let rowHover = Color("F2F2F2")
    static let textPrimary = Color("464A60")
    static let textSecondary = Color("6D6C71")
    static let accentColor = Color("464A60")
    static let accentDark = Color("1B1F33")
    static let iconSecondary = Color("9E9DA5")
    static let divider = Color("E4E4E4")
    static let iconBackground = Color("EAEAEA")
    static let shortcutBackground = Color("F0F0F0")
    static let templateTitleColor = Color("9B9B9B")

    init(_ hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
