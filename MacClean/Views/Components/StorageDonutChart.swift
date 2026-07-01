import SwiftUI

struct StorageDonutChart: View {
    let segments: [StorageSegment]
    var size: CGFloat = 160
    var lineWidth: CGFloat = 30

    private var total: Double {
        segments.reduce(0) { $0 + $1.value }
    }

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color.progressTrack, lineWidth: lineWidth)

            // Colored segments
            ForEach(computedSegments, id: \.id) { segment in
                DonutSegment(
                    startAngle: segment.startAngle,
                    endAngle: segment.endAngle,
                    color: segment.color,
                    lineWidth: lineWidth
                )
            }

            // Center text
            VStack(spacing: 2) {
                Text(totalFormatted)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                Text("Total")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .frame(width: size, height: size)
    }

    private var totalFormatted: String {
        FileSizeFormatter.string(from: Int64(total))
    }

    private var computedSegments: [ComputedSegment] {
        guard total > 0 else { return [] }
        var start: Double = 0
        return segments.map { seg in
            let fraction = seg.value / total
            let end = start + fraction * 360
            let computed = ComputedSegment(
                id: seg.id,
                startAngle: .degrees(start),
                endAngle: .degrees(end),
                color: seg.color
            )
            start = end
            return computed
        }
    }
}

struct StorageSegment: Identifiable {
    let id = UUID()
    let value: Double
    let color: Color
    let label: String
}

private struct ComputedSegment: Identifiable {
    let id: UUID
    let startAngle: Angle
    let endAngle: Angle
    let color: Color
}

struct DonutSegment: View {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color
    let lineWidth: CGFloat

    private var startRatio: CGFloat {
        CGFloat(startAngle.degrees / 360)
    }

    private var endRatio: CGFloat {
        CGFloat(endAngle.degrees / 360)
    }

    private var length: CGFloat {
        endRatio - startRatio
    }

    var body: some View {
        Circle()
            .trim(from: startRatio, to: endRatio)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
            .rotationEffect(.degrees(-90))
    }
}

#Preview {
    StorageDonutChart(segments: [
        StorageSegment(value: 200, color: .storageUsed, label: "Used"),
        StorageSegment(value: 100, color: .storageSystem, label: "System"),
        StorageSegment(value: 300, color: .storageFree, label: "Free"),
    ])
}
