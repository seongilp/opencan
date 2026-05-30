import SwiftUI

/// Dark palette approximating the LocalCan look.
enum Theme {
    static let bg          = Color(red: 0.043, green: 0.043, blue: 0.051)
    static let sidebar     = Color(red: 0.063, green: 0.063, blue: 0.071)
    static let card        = Color(red: 0.098, green: 0.098, blue: 0.110)
    static let cardInner   = Color(red: 0.075, green: 0.075, blue: 0.086)
    static let stroke      = Color.white.opacity(0.07)
    static let strokeStrong = Color.white.opacity(0.12)
    static let textPrimary  = Color.white.opacity(0.92)
    static let textSecondary = Color.white.opacity(0.42)
    static let textTertiary  = Color.white.opacity(0.28)
    static let green        = Color(red: 0.22, green: 0.80, blue: 0.40)
    static let pill         = Color.white.opacity(0.06)

    static let cardRadius: CGFloat = 14
    static let sidebarWidth: CGFloat = 248
}

extension View {
    /// Hairline-bordered rounded card surface.
    func cardSurface(_ fill: Color = Theme.card, radius: CGFloat = Theme.cardRadius) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }
}
