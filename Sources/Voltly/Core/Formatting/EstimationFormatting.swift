import Foundation

public enum EstimationFormatting {
    public static func estimatedPrefix(isEstimated: Bool) -> String {
        isEstimated ? "~ Tahmini " : ""
    }
}
