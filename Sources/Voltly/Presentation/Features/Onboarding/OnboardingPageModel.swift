import Foundation

/// Onboarding adımlarını tek bir model ile tanımlar.
public struct OnboardingPageModel: Identifiable, Equatable, Sendable {
    public let type: OnboardingPageType
    public let title: String
    public let subtitle: String
    public let chips: [String]
    public let metricSamples: [OnboardingMetricSample]

    public var id: Int { type.rawValue }

    public init(
        type: OnboardingPageType,
        title: String,
        subtitle: String,
        chips: [String] = [],
        metricSamples: [OnboardingMetricSample] = []
    ) {
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.chips = chips
        self.metricSamples = metricSamples
    }
}

/// Maliyet adımında gösterilen örnek metrik verisi.
public struct OnboardingMetricSample: Equatable, Sendable {
    public let value: String
    public let label: String

    public init(value: String, label: String) {
        self.value = value
        self.label = label
    }
}

public extension OnboardingPageModel {
    static let defaultPages: [OnboardingPageModel] = [
        OnboardingPageModel(
            type: .splash,
            title: "Voltly",
            subtitle: "Şarjını, maliyetini ve verimini takip et."
        ),
        OnboardingPageModel(
            type: .welcome,
            title: "Elektrikli araç şarj takibini kolaylaştır",
            subtitle: "Seanslarını kaydet, maliyeti gör, kullanımını net takip et.",
            chips: ["kWh", "TL", "SOC", "AC/DC"]
        ),
        OnboardingPageModel(
            type: .costAnalysis,
            title: "Gerçek maliyetini anında gör",
            subtitle: "TL/kWh, TL/100 km ve aylık trendi tek ekranda izle.",
            metricSamples: [
                OnboardingMetricSample(value: "5.42", label: "TL/kWh"),
                OnboardingMetricSample(value: "17.8", label: "TL / 100 km")
            ]
        ),
        OnboardingPageModel(
            type: .comparison,
            title: "AC ve DC şarjı karşılaştır",
            subtitle: "Daha ekonomik şarj tipini ve fiyat farklarını hızlıca gör."
        ),
        OnboardingPageModel(
            type: .accountChoice,
            title: "Nasıl devam etmek istersin?",
            subtitle: ""
        )
    ]
}
