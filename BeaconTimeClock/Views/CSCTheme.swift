// FILE PURPOSE: Central colors and reusable surface treatments for the website-inspired UI.
import SwiftUI
import UIKit

/// Container Supply-inspired design tokens.
/// Public website: restrained industrial typography, large whitespace,
/// white surfaces, and a blue/navy palette. These are app-specific colors,
/// not a claim to reproduce the company's unpublished brand standards.
// This type groups related state and behavior under a clear responsibility.
enum CSCTheme {
    static let navy = Color(red: 0.045, green: 0.153, blue: 0.272)
    static let blue = Color(red: 0.105, green: 0.345, blue: 0.505)
    static let steel = Color(red: 0.355, green: 0.515, blue: 0.625)
    static let amber = Color(red: 0.76, green: 0.47, blue: 0.18)

    // Dynamic UIColor providers retain legibility in Light and Dark Mode.
    static let ink = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
          ? UIColor(red: 0.91, green: 0.95, blue: 0.98, alpha: 1)
          : UIColor(red: 0.045, green: 0.153, blue: 0.272, alpha: 1)
    })
    static let canvas = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
          ? UIColor(red: 0.06, green: 0.10, blue: 0.14, alpha: 1)
          : UIColor(red: 0.957, green: 0.971, blue: 0.980, alpha: 1)
    })
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let border = Color(uiColor: .separator).opacity(0.33)
}

/// Consistent, native surface: card spacing and contrast are shared across roles.
// This type groups related state and behavior under a clear responsibility.
struct CSCCard<Content: View>: View {
    @ViewBuilder let content: Content

    // Create this object with the dependencies or state it needs; avoid hidden global services.
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    // The SwiftUI body describes the visible screen from the current state.
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(CSCTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(CSCTheme.border, lineWidth: 1)
            }
    }
}

/// Applied to List/Form views so every department screen uses one palette.
// This type groups related state and behavior under a clear responsibility.
struct CSCListStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(CSCTheme.canvas)
            .tint(CSCTheme.blue)
    }
}

extension View {
    func cscListStyle() -> some View { modifier(CSCListStyle()) }
}
