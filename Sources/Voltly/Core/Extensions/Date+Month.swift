import Foundation

public extension Date {
    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }

    var endOfMonth: Date {
        let calendar = Calendar.current
        let start = startOfMonth
        guard let next = calendar.date(byAdding: .month, value: 1, to: start),
              let end = calendar.date(byAdding: .second, value: -1, to: next) else {
            return self
        }
        return end
    }
}
