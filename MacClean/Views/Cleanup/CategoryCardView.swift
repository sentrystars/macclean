import SwiftUI

struct CategoryCardView: View {
    let category: CleanupCategory
    let sizeBytes: Int64
    var isSelected: Bool = false
    var onTap: (() -> Void)?
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.iconName)
                .font(.title2)
                .foregroundColor(category.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                if sizeBytes > 0 {
                    Text(FileSizeFormatter.string(from: sizeBytes))
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                } else {
                    Text(category.description)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if category.requiresSudo {
                Image(systemName: "lock.shield")
                    .font(.caption)
                    .foregroundColor(.riskCaution)
            }

            StatusIcon(riskLevel: category.riskLevel)
                .font(.caption)
        }
        .padding(12)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .appShadow, radius: isHovering ? 4 : 2)
        .scaleEffect(isHovering ? 1.02 : 1)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

#Preview {
    VStack {
        CategoryCardView(category: .userCaches, sizeBytes: 1_234_567_890)
        CategoryCardView(category: .claudeVM, sizeBytes: 10_737_418_240)
        CategoryCardView(category: .systemCaches, sizeBytes: 0)
    }
    .padding()
}
