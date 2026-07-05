import SwiftUI

struct AnimatedProgressBar: View {
    let value: Double
    let color: Color
    var trackColor: Color = .progressTrack
    var height: CGFloat = 8
    @State private var pulseOpacity: Double = 1.0

    private var isScanning: Bool { value > 0 && value < 1 }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackColor.opacity(isScanning ? 0.5 : 1.0))
                    .frame(height: height)

                Capsule()
                    .fill(color.opacity(isScanning ? pulseOpacity : 1.0))
                    .frame(width: geometry.size.width * CGFloat(min(max(value, 0), 1)))
                    .frame(height: height)
                    .animation(.easeInOut(duration: 0.3), value: value)
            }
        }
        .frame(height: height)
        .onAppear {
            if isScanning {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulseOpacity = 0.5
                }
            }
        }
        .onChange(of: isScanning) { _, scanning in
            if scanning {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulseOpacity = 0.5
                }
            } else {
                withAnimation(.default) {
                    pulseOpacity = 1.0
                }
            }
        }
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
