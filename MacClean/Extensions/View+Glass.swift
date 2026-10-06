import SwiftUI

/// Liquid Glass（macOS 26+）适配层。
///
/// 设计原则：只在容器上用玻璃（卡片/面板），不给每一行加玻璃，
/// 避免大量 glassEffect 带来的渲染开销；低版本系统自动回退到原有卡片样式。
struct GlassPanelModifier: ViewModifier {
    var cornerRadius: CGFloat = 14
    var tint: Color?
    var interactive: Bool = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            let effect: Glass = tint.map { .regular.tint($0) } ?? .regular
            content.glassEffect(
                interactive ? effect.interactive() : effect,
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            content
                .background(
                    tint.map { AnyShapeStyle($0.opacity(0.12)) } ?? AnyShapeStyle(Color.appCard)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.textSecondary.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .appShadow, radius: 4, y: 1)
        }
    }
}

extension View {
    /// 玻璃面板容器。
    func glassPanel(cornerRadius: CGFloat = 14, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(GlassPanelModifier(cornerRadius: cornerRadius, tint: tint, interactive: interactive))
    }

    /// 主按钮：macOS 26+ 用玻璃高亮按钮。
    @ViewBuilder
    func glassProminentButton() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    /// 次级按钮：macOS 26+ 用玻璃按钮。
    @ViewBuilder
    func glassButton() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    /// 窗口底色：给玻璃提供可折射的背景。
    func appWindowBackground() -> some View {
        background(Color.appBackgroundGradient)
    }
}
