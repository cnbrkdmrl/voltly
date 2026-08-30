import Foundation

public struct EVChargeOperator: Identifiable, Hashable, Codable, Sendable {
    public var id: String { name }
    public let name: String

    public init(name: String) {
        self.name = name
    }

    public static let turkiye: [EVChargeOperator] = [
        EVChargeOperator(name: "ZES"),
        EVChargeOperator(name: "Eşarj"),
        EVChargeOperator(name: "Trugo"),
        EVChargeOperator(name: "Sharz"),
        EVChargeOperator(name: "Voltrun"),
        EVChargeOperator(name: "Beefull"),
        EVChargeOperator(name: "Wat Mobilite"),
        EVChargeOperator(name: "RHG Enertürk"),
        EVChargeOperator(name: "Astor Şarj"),
        EVChargeOperator(name: "Powerşarj"),
        EVChargeOperator(name: "ChargeIQ"),
        EVChargeOperator(name: "Electrip"),
        EVChargeOperator(name: "GreenWay"),
        EVChargeOperator(name: "Ionity")
    ]
}
