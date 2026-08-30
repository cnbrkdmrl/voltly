import Foundation

public struct InsightComposer {
    public init() {}

    public func dcReductionMessage(current: Double, target: Double) -> String {
        "DC oranını %\(Int(current.rounded())) → %\(Int(target.rounded())) seviyesine çekmek maliyeti dengeler."
    }

    public func acIncreaseMessage(target: Double) -> String {
        "AC payını %\(Int(target.rounded())) üzerine çıkarmak daha dengeli bir maliyet sağlar."
    }

    public func homeIncreaseMessage(target: Double) -> String {
        "Ev şarjı payını %\(Int(target.rounded())) üstüne taşımak tasarrufu artırabilir."
    }

    public func entryConsistencyMessage(target: Double) -> String {
        "Bu ay en az \(Int(target.rounded())) kayıt girmek analizleri güçlendirir."
    }

    public func spendingTargetMessage(amount: Double, currencyCode: String) -> String {
        "Aylık harcamayı \(NumberFormatting.currency(amount, code: currencyCode)) altında tutmayı dene."
    }
}
