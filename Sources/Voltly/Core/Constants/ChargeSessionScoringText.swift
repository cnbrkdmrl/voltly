import Foundation

public enum ChargeSessionScoringText {
    public static let title = "Şarj Seansı Skoru"
    public static let priceTitle = "Fiyat"
    public static let efficiencyTitle = "Verim"
    public static let rangeTitle = "Şarj Aralığı"
    public static let recentSectionTitle = "Son Şarj Skorları"

    public static func labelTitle(_ label: ChargeSessionScoreLabel) -> String {
        switch label {
        case .veryGood: return "Çok iyi"
        case .good: return "İyi"
        case .average: return "Ortalama"
        case .expensive: return "Pahalı"
        case .inefficient: return "Verimsiz"
        }
    }

    public static func scoreSummary(score: Double, label: ChargeSessionScoreLabel) -> String {
        "\(NumberFormatting.oneDecimal(score))/10 • \(labelTitle(label))"
    }

    public static func sessionBadgeTitle(for label: ChargeSessionScoreLabel) -> String {
        switch label {
        case .veryGood, .good:
            return "İyi seçim"
        case .average:
            return "Ortalama"
        case .expensive, .inefficient:
            return "Pahalı seçim"
        }
    }

    public static func postSaveTitle(for report: ChargeSessionScoreReport) -> String {
        sessionBadgeTitle(for: report.label)
    }

    public static func postSaveMessage(for report: ChargeSessionScoreReport) -> String {
        if let preferred = preferredToastInsight(in: report.insights) {
            return preferred
        }

        switch report.label {
        case .veryGood, .good:
            return "İyi seçim. Bu seans genel ortalamana göre dengeli görünüyor."
        case .average:
            return "Seans ortalama bantta. Bir sonraki kayıtta maliyeti biraz daha düşürebilirsin."
        case .expensive, .inefficient:
            return "Bu seans maliyet baskısı oluşturdu. Bir sonraki şarjda AC/ev seçeneğini değerlendir."
        }
    }

    public static func moreExpensiveComment(deltaPercent: Double) -> String {
        "Bu şarj ortalamandan %\(Int(deltaPercent.rounded())) daha pahalı."
    }

    public static func cheaperComment(deltaPercent: Double) -> String {
        "Bu şarj ortalamandan %\(Int(deltaPercent.rounded())) daha uygun."
    }

    public static func efficiencyWorseComment(deltaPercent: Double) -> String {
        "Bu seansın TL/100 km değeri ortalamandan %\(Int(deltaPercent.rounded())) daha yüksek."
    }

    public static func efficiencyBetterComment(deltaPercent: Double) -> String {
        "Bu seansın TL/100 km değeri ortalamandan %\(Int(deltaPercent.rounded())) daha iyi."
    }

    public static let healthyRangeComment = "Şarj aralığın sağlıklı."
    public static let lowStartComment = "Şarja çok düşük yüzdeyle başlamak rutinde daha fazla maliyet baskısı yaratabilir."
    public static let highEndDCComment = "DC seansını %90 üstüne taşımak süreyi ve maliyeti artırabilir."
    public static let wideRangeComment = "Çok geniş şarj aralığı seans süresini uzatabilir."
    public static let estimatedEfficiencyComment = "Verim skoru kısmen tahmini tüketim verisiyle hesaplandı."
    public static let missingDataComment = "Daha net skor için enerji, süre ve km verisini daha düzenli gir."

    public static func dcUsageComment(dcRatio: Double) -> String {
        "DC oranı yüksek olduğu için maliyet artmış olabilir."
    }

    private static func preferredToastInsight(in insights: [ChargeSessionScoreInsight]) -> String? {
        // Keep ordering deterministic so the same session always yields the same message.
        let preferredIDs = [
            "price-delta",
            "healthy-range",
            "efficiency-delta",
            "dc-ratio",
            "dc-high-end",
            "wide-range",
            "low-start",
            "estimated-efficiency",
            "missing-data"
        ]

        for id in preferredIDs {
            if let message = insights.first(where: { $0.id == id })?.message {
                return message
            }
        }
        return insights.first?.message
    }
}
