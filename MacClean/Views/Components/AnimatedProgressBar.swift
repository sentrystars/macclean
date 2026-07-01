import SwiftUI

struct AnimatedProgressBar: View {
    let value: Double
    let color: Color
    var trackColor: Color = .progressTrack
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackColor)
                    .frame(height: height)

                Capsule()
                    .fill(color)
                    .frame(width: geometry.size.width * CGFloat(min(max(value, 0), 1)))
                    .frame(height: height)
                    .animation(.easeInOut(duration: 0.3), value: value)
            }
        }
        .frame(height: height)
    }
}

#Preview {
    VStack {
        AnimatedProgressBar(value: 0.3, color: .blue)
        AnimatedProgressBar(value: 0.7, color: .green)
        AnimatedProgressBar(value: 1.0, color: .orange)
    }
    .padding()
}
