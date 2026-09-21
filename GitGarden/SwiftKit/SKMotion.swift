import SwiftUI

struct SKShimmer: ViewModifier {
    @State private var phase: CGFloat = -0.8

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: [.clear, .white.opacity(0.55), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(12))
                .offset(x: phase * 280)
                .blendMode(.plusLighter)
            }
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    phase = 0.8
                }
            }
    }
}

struct SKGlowSweep: ViewModifier {
    var tint: Color = SKTheme.accent
    @State private var glow = false

    func body(content: Content) -> some View {
        content
            .shadow(color: tint.opacity(glow ? 0.45 : 0.12), radius: glow ? 16 : 6, y: 4)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }
    }
}

struct SKHoverLift: ViewModifier {
    var rotate: Bool = false
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering ? 1.03 : 1)
            .rotationEffect(.degrees(hovering && rotate ? -3.5 : 0))
            .shadow(
                color: .black.opacity(hovering ? 0.14 : 0.05),
                radius: hovering ? 22 : 10,
                y: hovering ? 12 : 6
            )
            .animation(SKMotion.lift, value: hovering)
            .onHover { hovering = $0 }
    }
}

extension View {
    func skShimmer() -> some View { modifier(SKShimmer()) }
    func skGlow(_ tint: Color = SKTheme.accent) -> some View { modifier(SKGlowSweep(tint: tint)) }
    func skLift(rotate: Bool = false) -> some View { modifier(SKHoverLift(rotate: rotate)) }
}
