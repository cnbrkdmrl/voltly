import Foundation

public protocol UsageModeStore {
    func loadUsageMode() -> UsageMode
    func saveUsageMode(_ mode: UsageMode)
}
