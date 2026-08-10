import SwiftUI

// MARK: - Design Tokens

enum DS {
    static let bg = Color(red: 0.07, green: 0.07, blue: 0.10)
    static let surface = Color(red: 0.12, green: 0.12, blue: 0.17)
    static let surfaceHover = Color(red: 0.16, green: 0.16, blue: 0.22)
    static let border = Color.white.opacity(0.08)
    static let borderBright = Color.white.opacity(0.15)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let textMuted = Color.white.opacity(0.3)

    static let cpuColor  = Color(red: 0.36, green: 0.72, blue: 1.0)    // sky blue
    static let memColor  = Color(red: 0.56, green: 0.42, blue: 1.0)    // violet
    static let netInColor  = Color(red: 0.28, green: 0.90, blue: 0.60) // mint
    static let netOutColor = Color(red: 1.0,  green: 0.60, blue: 0.20) // amber

    static let cornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 16
    static let spacing: CGFloat = 12
}

// MARK: - Card Container

struct MetricCard<Content: View>: View {
    let content: Content
    var glowColor: Color = .clear

    init(glowColor: Color = .clear, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.glowColor = glowColor
    }

    var body: some View {
        content
            .padding(DS.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                    .fill(DS.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                            .stroke(DS.border, lineWidth: 1)
                    )
                    .shadow(color: glowColor.opacity(0.12), radius: 20, x: 0, y: 0)
            )
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let subtitle: String?
    let color: Color

    init(_ title: String, subtitle: String? = nil, color: Color = DS.textPrimary) {
        self.title = title
        self.subtitle = subtitle
        self.color = color
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .shadow(color: color.opacity(0.8), radius: 4)
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(DS.textPrimary)
            if let sub = subtitle {
                Text(sub)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(DS.textSecondary)
            }
            Spacer()
        }
    }
}

// MARK: - Byte Formatter

func formatBytes(_ bytes: Double, perSecond: Bool = false) -> String {
    let suffix = perSecond ? "/s" : ""
    switch bytes {
    case ..<1024: return String(format: "%.0f B\(suffix)", bytes)
    case ..<(1024 * 1024): return String(format: "%.1f KB\(suffix)", bytes / 1024)
    case ..<(1024 * 1024 * 1024): return String(format: "%.1f MB\(suffix)", bytes / 1_048_576)
    default: return String(format: "%.2f GB\(suffix)", bytes / 1_073_741_824)
    }
}
