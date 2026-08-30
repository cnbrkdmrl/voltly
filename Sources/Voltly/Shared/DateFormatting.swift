import Foundation

public extension DateFormatter {
    static let monthKey: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()
}
