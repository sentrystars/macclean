import SwiftUI

#if os(macOS)
import AppKit
#endif

extension Color {
    init(light: Self, dark: Self) {
#if os(macOS)
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.name == .darkAqua ? NSColor(dark) : NSColor(light)
        })
#else
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
#endif
    }

    // MARK: - Brand
    static let appAccent = Color(red: 0, green: 0.478, blue: 1.0)
    static let appBackground = Color(
        light: Color(red: 0.96, green: 0.96, blue: 0.97),
        dark: Color(red: 0.08, green: 0.08, blue: 0.09)
    )
    static let appSidebar = Color(
        light: Color(red: 0.925, green: 0.925, blue: 0.929),
        dark: Color(red: 0.11, green: 0.11, blue: 0.12)
    )
    static let appCard = Color(
        light: Color(red: 1, green: 1, blue: 1),
        dark: Color(red: 0.15, green: 0.15, blue: 0.16)
    )

    /// 窗口渐变底色：Liquid Glass 需要背景才有折射层次。
    static let appBackgroundGradient = LinearGradient(
        colors: [
            Color(light: Color(red: 0.949, green: 0.957, blue: 0.980),
                  dark: Color(red: 0.067, green: 0.071, blue: 0.094)),
            Color(light: Color(red: 0.886, green: 0.906, blue: 0.949),
                  dark: Color(red: 0.114, green: 0.118, blue: 0.153)),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 侧栏底色（玻璃下方的冷色层）。
    static let appSidebarGradient = LinearGradient(
        colors: [
            Color(light: Color(red: 0.925, green: 0.937, blue: 0.965),
                  dark: Color(red: 0.086, green: 0.090, blue: 0.114)),
            Color(light: Color(red: 0.878, green: 0.894, blue: 0.933),
                  dark: Color(red: 0.106, green: 0.110, blue: 0.141)),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Risk Levels
    static let riskSafe = Color(red: 0.204, green: 0.78, blue: 0.349)
    static let riskCaution = Color(red: 1.0, green: 0.584, blue: 0.0)
    static let riskWarning = Color(red: 1.0, green: 0.231, blue: 0.188)

    // MARK: - Storage Chart
    static let storageUsed = Color(red: 0, green: 0.478, blue: 1.0)
    static let storageSystem = Color(red: 1.0, green: 0.584, blue: 0.0)
    static let storageFree = Color(
        light: Color(red: 0.898, green: 0.898, blue: 0.902),
        dark: Color(red: 0.3, green: 0.3, blue: 0.31)
    )

    // MARK: - Progress
    static let progressTrack = Color(
        light: Color(red: 0.898, green: 0.898, blue: 0.902),
        dark: Color(red: 0.25, green: 0.25, blue: 0.26)
    )
    static let progressFill = Color(red: 0, green: 0.478, blue: 1.0)

    // MARK: - Text
    static let textPrimary = Color(
        light: Color(red: 0.11, green: 0.11, blue: 0.118),
        dark: Color(red: 0.92, green: 0.92, blue: 0.93)
    )
    static let textSecondary = Color(
        light: Color(red: 0.557, green: 0.557, blue: 0.576),
        dark: Color(red: 0.65, green: 0.65, blue: 0.67)
    )

    // MARK: - Shadows
    static let appShadow = Color(
        light: Color.black.opacity(0.06),
        dark: Color.white.opacity(0.04)
    )
}