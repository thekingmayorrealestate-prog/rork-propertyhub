import SwiftUI

enum Theme {
    static let canvas = Color(hex: 0xF6F1E7)
    static let sand = Color(hex: 0xECE4D4)
    static let surface = Color.white
    static let primary = Color(hex: 0x1F4D3A)
    static let primarySoft = Color(hex: 0xE3ECE6)
    static let accent = Color(hex: 0xC98B3C)
    static let accentSoft = Color(hex: 0xF6EAD7)
    static let ink = Color(hex: 0x1B2420)
    static let muted = Color(hex: 0x6B6F68)
    static let hairline = Color(hex: 0xE7E0D2)
    static let danger = Color(hex: 0xB9442F)
    static let cardRadius: CGFloat = 18
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum BadgeTone {
    case success, warning, info, neutral, danger, accent

    var foreground: Color {
        switch self {
        case .success: Color(hex: 0x1E7A47)
        case .warning: Color(hex: 0xA2600F)
        case .info: Color(hex: 0x2B62A8)
        case .neutral: Color(hex: 0x5D605A)
        case .danger: Color(hex: 0xA93A26)
        case .accent: Theme.accent
        }
    }

    var background: Color {
        switch self {
        case .success: Color(hex: 0xDFF2E5)
        case .warning: Color(hex: 0xFBE6C6)
        case .info: Color(hex: 0xDCE9F8)
        case .neutral: Color(hex: 0xEEEDE8)
        case .danger: Color(hex: 0xF8DFD9)
        case .accent: Theme.accentSoft
        }
    }
}

extension BookingStatus {
    var tone: BadgeTone {
        switch self {
        case .pending: .warning
        case .confirmed, .completed: .success
        case .viewingScheduled: .info
        case .declined: .danger
        case .cancelled: .neutral
        }
    }
}

extension ListingStatus {
    var tone: BadgeTone {
        switch self {
        case .pending: .warning
        case .live: .success
        case .rejected: .danger
        case .unavailable: .neutral
        }
    }
}

extension PaymentStatus {
    var tone: BadgeTone {
        switch self {
        case .paid: .success
        case .pending: .neutral
        case .failed: .danger
        case .refunded: .info
        }
    }
}

struct StatusBadge: View {
    let text: String
    let tone: BadgeTone
    var showsDot: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if showsDot {
                Circle().fill(tone.foreground).frame(width: 6, height: 6)
            }
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tone.foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tone.background, in: .capsule)
    }
}

struct CardModifier: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.cardRadius))
            .shadow(color: Theme.ink.opacity(0.05), radius: 14, y: 4)
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }

    func screenBackground() -> some View {
        background(Theme.canvas.ignoresSafeArea())
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 20)
            .background(isEnabled ? Theme.primary : Theme.muted.opacity(0.4), in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 16)
            .background(Theme.surface, in: .capsule)
            .overlay(Capsule().strokeBorder(tint.opacity(0.85), lineWidth: 1.5))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
