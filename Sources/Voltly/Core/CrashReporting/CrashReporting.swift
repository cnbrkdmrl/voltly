import Foundation

public protocol CrashReporting {
    func log(_ message: String)
    func record(error: Error, additionalInfo: [String: Any]?)
}

public final class NoopCrashReporter: CrashReporting {
    public init() {}

    public func log(_ message: String) {}

    public func record(error: Error, additionalInfo: [String: Any]?) {}
}
