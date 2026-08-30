import Foundation

public protocol ChargingOperatorRepository {
    func visibleOperators() throws -> [ChargingOperator]
    func favoriteOperators() throws -> [ChargingOperator]
    func hiddenOperators() throws -> [ChargingOperator]
    func `operator`(byCode code: String) throws -> ChargingOperator?
    func seedIfNeeded() throws
    func setFavorite(operatorCode: String, isFavorite: Bool) throws
    func setHidden(operatorCode: String, isHidden: Bool) throws
}
