import SwiftUI

struct FileSizeText: View {
    let bytes: Int64
    var font: Font = .body
    var color: Color = .textPrimary

    var body: some View {
        Text(FileSizeFormatter.string(from: bytes))
            .font(font)
            .foregroundColor(color)
            .monospacedDigit()
    }
}

#Preview {
    VStack {
        FileSizeText(bytes: 1024)
        FileSizeText(bytes: 1_048_576, font: .title, color: .blue)
        FileSizeText(bytes: 1_073_741_824, font: .largeTitle, color: .green)
    }
    .padding()
}
