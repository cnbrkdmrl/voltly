import SwiftUI

/// Maliyet metriklerini ve trend fikrini anlatan onboarding adımı.
public struct CostAnalysisStepView: View {
    private let page: OnboardingPageModel

    @State private var reveal = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(page: OnboardingPageModel) {
        self.page = page
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTokens.Spacing.xLarge) {
            Text(page.title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .accessibilityAddTraits(.isHeader)
                .opacity(reveal ? 1 : 0)
                .offset(y: reveal ? 0 : OnboardingTokens.reducedOffset(OnboardingTokens.Motion.mediumOffset, reduceMotion: reduceMotion))
                .animation(revealAnimation(delay: 0.02), value: reveal)

            Text(page.subtitle)
                .font(.body)
                .foregroundStyle(Color.secondary.opacity(0.95))
                .opacity(reveal ? 1 : 0)
                .offset(y: reveal ? 0 : OnboardingTokens.reducedOffset(OnboardingTokens.Motion.mediumOffset, reduceMotion: reduceMotion))
                .animation(revealAnimation(delay: 0.08), value: reveal)

            MiniTrendCard(animate: reveal, reduceMotion: reduceMotion)
                .opacity(reveal ? 1 : 0)
                .offset(y: reveal ? 0 : OnboardingTokens.reducedOffset(OnboardingTokens.Motion.smallOffset, reduceMotion: reduceMotion))
                .animation(revealAnimation(delay: 0.14), value: reveal)

            metricCardsLayout
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            reveal = true
        }
    }

    @ViewBuilder
    private var metricCardsLayout: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: OnboardingTokens.Spacing.medium) {
                ForEach(Array(page.metricSamples.enumerated()), id: \.offset) { index, sample in
                    MetricCard(value: sample.value, subtitle: sample.label)
                        .opacity(reveal ? 1 : 0)
                        .offset(y: reveal ? 0 : OnboardingTokens.reducedOffset(OnboardingTokens.Motion.mediumOffset, reduceMotion: reduceMotion))
                        .animation(revealAnimation(delay: 0.20 + (Double(index) * 0.08)), value: reveal)
                }
            }
        } else {
            HStack(spacing: OnboardingTokens.Spacing.medium) {
                ForEach(Array(page.metricSamples.enumerated()), id: \.offset) { index, sample in
                    MetricCard(value: sample.value, subtitle: sample.label)
                        .opacity(reveal ? 1 : 0)
                        .offset(y: reveal ? 0 : OnboardingTokens.reducedOffset(OnboardingTokens.Motion.mediumOffset, reduceMotion: reduceMotion))
                        .animation(revealAnimation(delay: 0.20 + (Double(index) * 0.08)), value: reveal)
                }
            }
        }

        Spacer(minLength: 0)
    }

    private func revealAnimation(delay: Double) -> Animation {
        OnboardingTokens.revealAnimation(reduceMotion: reduceMotion, delay: delay)
    }
}

/// Maliyet trendinin soldan sağa çizilme hissini veren örnek grafik kartı.
private struct MiniTrendCard: View {
    let animate: Bool
    let reduceMotion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTokens.Spacing.medium) {
            Text("Aylık trend")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.secondary)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                    OnboardingTrendLineShape()
                        .trim(from: 0, to: animate ? 1 : 0.01)
                        .stroke(
                            LinearGradient(
                                colors: [OnboardingStyle.accentDark, OnboardingStyle.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .animation(
                            reduceMotion ? .easeOut(duration: 0.16) : .easeOut(duration: OnboardingTokens.Motion.trendDuration).delay(0.16),
                            value: animate
                        )
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(height: OnboardingTokens.Size.miniTrendHeight)
        }
        .padding(OnboardingTokens.Spacing.xLarge)
        .background(
            RoundedRectangle(cornerRadius: OnboardingTokens.CornerRadius.large, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Aylık trend örneği")
        .accessibilityValue("Maliyet değişimini zaman içinde takip edebilirsin.")
    }
}

/// Onboarding örnek trend çizgisi için küçük bir shape.
private struct OnboardingTrendLineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = CGPoint(x: rect.minX, y: rect.maxY * 0.72)
        path.move(to: start)
        path.addCurve(
            to: CGPoint(x: rect.width * 0.36, y: rect.height * 0.35),
            control1: CGPoint(x: rect.width * 0.14, y: rect.height * 0.82),
            control2: CGPoint(x: rect.width * 0.24, y: rect.height * 0.22)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.70, y: rect.height * 0.56),
            control1: CGPoint(x: rect.width * 0.48, y: rect.height * 0.48),
            control2: CGPoint(x: rect.width * 0.58, y: rect.height * 0.70)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.height * 0.20),
            control1: CGPoint(x: rect.width * 0.80, y: rect.height * 0.42),
            control2: CGPoint(x: rect.width * 0.90, y: rect.height * 0.18)
        )
        return path
    }
}

#if DEBUG
struct CostAnalysisStepView_Previews: PreviewProvider {
    static var previews: some View {
        CostAnalysisStepView(page: .defaultPages[2])
            .padding(20)
    }
}
#endif
