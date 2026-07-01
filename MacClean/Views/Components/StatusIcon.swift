import SwiftUI

struct StatusIcon: View {
    let riskLevel: RiskLevel
    var size: CGFloat = 16

    var body: some View {
        Image(systemName: iconName)
            .foregroundColor(iconColor)
            .font(.system(size: size))
            .help(riskLevel.rawValue.capitalized)
    }

    private var iconName: String {
        switch riskLevel {
        case .safe: return "checkmark.circle.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .warning: return "xmark.octagon.fill"
        }
    }

    private var iconColor: Color {
        switch riskLevel {
        case .safe: return .riskSafe
        case .caution: return .riskCaution
        case .warning: return .riskWarning
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        StatusIcon(riskLevel: .safe)
        StatusIcon(riskLevel: .caution)
        StatusIcon(riskLevel: .warning)
    }
    .padding()
}
