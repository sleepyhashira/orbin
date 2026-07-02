import SwiftUI

// MARK: - Hex Color Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
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

// MARK: - Obsidian Amber Palette

extension Color {
    // Surfaces
    static let obsidianBackground = Color(hex: "#131315")
    static let obsidianSurface = Color(hex: "#131315")
    static let obsidianSurfaceDim = Color(hex: "#131315")
    static let obsidianSurfaceBright = Color(hex: "#39393b")
    static let obsidianSurfaceContainerLowest = Color(hex: "#0e0e10")
    static let obsidianSurfaceContainerLow = Color(hex: "#1b1b1d")
    static let obsidianSurfaceContainer = Color(hex: "#201f21")
    static let obsidianSurfaceContainerHigh = Color(hex: "#2a2a2c")
    static let obsidianSurfaceContainerHighest = Color(hex: "#353437")

    // Primary (Amber)
    static let obsidianPrimary = Color(hex: "#ffb693")
    static let obsidianOnPrimary = Color(hex: "#561f00")
    static let obsidianPrimaryContainer = Color(hex: "#ff7a2f")
    static let obsidianOnPrimaryContainer = Color(hex: "#612400")
    static let obsidianInversePrimary = Color(hex: "#a04100")
    static let obsidianPrimaryFixed = Color(hex: "#ffdbcc")

    // Secondary (Slate)
    static let obsidianSecondary = Color(hex: "#c8c5cb")
    static let obsidianOnSecondary = Color(hex: "#303034")
    static let obsidianSecondaryContainer = Color(hex: "#47464b")
    static let obsidianOnSecondaryContainer = Color(hex: "#b6b4b9")

    // Tertiary
    static let obsidianTertiary = Color(hex: "#c8c6c8")
    static let obsidianOnTertiary = Color(hex: "#303032")
    static let obsidianTertiaryContainer = Color(hex: "#a2a0a2")
    static let obsidianOnTertiaryContainer = Color(hex: "#373739")

    // Content on Surface
    static let obsidianOnSurface = Color(hex: "#e5e1e4")
    static let obsidianOnSurfaceVariant = Color(hex: "#dfc0b2")
    static let obsidianOutline = Color(hex: "#a78b7f")
    static let obsidianOutlineVariant = Color(hex: "#584238")

    // Error
    static let obsidianError = Color(hex: "#ffb4ab")
    static let obsidianOnError = Color(hex: "#690005")
    static let obsidianErrorContainer = Color(hex: "#93000a")
    static let obsidianOnErrorContainer = Color(hex: "#ffdad6")

    // Glass effects
    static let obsidianGlassBorder = Color.white.opacity(0.10)
    static let obsidianGlassHover = Color.white.opacity(0.06)

    // Legacy compatibility
    static let appAccent = Color.obsidianPrimaryContainer
    static let appAccentSoft = Color.obsidianOnSurfaceVariant
}

// MARK: - Typography
// Uses system fonts with design variants that are always available on macOS.
// Hanken Grotesk → system .rounded  |  JetBrains Mono → system .monospaced

extension Font {
    static func appDisplayLarge() -> Font {
        .system(size: 28, weight: .bold, design: .rounded)
    }
    static func appHeadlineMedium() -> Font {
        .system(size: 20, weight: .semibold, design: .rounded)
    }
    static func appHeadlineSmall() -> Font {
        .system(size: 15, weight: .semibold, design: .rounded)
    }
    static func appBodyLarge() -> Font {
        .system(size: 14, weight: .regular, design: .default)
    }
    static func appBodyMedium() -> Font {
        .system(size: 13, weight: .regular, design: .default)
    }
    static func appBodySmall() -> Font {
        .system(size: 12, weight: .regular, design: .default)
    }
    static func appLabelCode() -> Font {
        .system(size: 11, weight: .medium, design: .monospaced)
    }
    static func appLabelCaps() -> Font {
        .system(size: 10, weight: .semibold, design: .rounded)
    }
}

// MARK: - Spacing & Radii

struct AppSpacing {
    static let unit: CGFloat = 4
    static let gutter: CGFloat = 16
    static let marginPage: CGFloat = 24
    static let stackSm: CGFloat = 8
    static let stackMd: CGFloat = 16
    static let stackLg: CGFloat = 32
}

struct AppCornerRadius {
    static let sm: CGFloat = 4
    static let defaultRadius: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 14
    static let xl: CGFloat = 20
    static let full: CGFloat = 9999
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    var isDisabled: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(isDisabled ? Color.obsidianOnPrimary.opacity(0.5) : Color.obsidianOnPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                LinearGradient(
                    colors: [Color.obsidianPrimary, Color.obsidianPrimaryContainer],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.defaultRadius))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var isDisabled: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(isDisabled ? Color.white.opacity(0.3) : Color.obsidianOnSurface)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.defaultRadius)
                    .fill(configuration.isPressed ? Color.obsidianGlassHover : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.defaultRadius)
                    .stroke(Color.obsidianGlassBorder, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    var isDisabled: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                LinearGradient(
                    colors: [Color.obsidianError, Color.obsidianErrorContainer],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.defaultRadius))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Compact button for inline contexts (inspector, table rows, etc.)
struct CompactButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(Color.obsidianOnSurface)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                    .fill(configuration.isPressed ? Color.obsidianGlassHover : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                    .stroke(Color.obsidianGlassBorder, lineWidth: 1)
            )
    }
}
