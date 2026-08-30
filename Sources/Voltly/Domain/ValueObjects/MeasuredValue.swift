import Foundation

public enum MeasuredValue<T: Equatable>: Equatable {
    case exact(T)
    case estimated(T)

    public var value: T {
        switch self {
        case .exact(let value), .estimated(let value):
            return value
        }
    }

    public var isEstimated: Bool {
        if case .estimated = self { return true }
        return false
    }
}
