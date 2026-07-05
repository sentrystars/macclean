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
    static let storageApps = Color(red: 0.204, green: 0.78, blue: 0.349)
    static let storageDocuments = Color(red: 0.345, green: 0.337, blue: 0.839)

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
