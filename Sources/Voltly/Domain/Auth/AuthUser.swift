import Foundation

public struct AuthUser: Identifiable, Equatable, Codable {
    public let id: String
    public var email: String?
    public var displayName: String?
    public var provider: AuthProvider
    public var createdAt: Date
    public var lastSignInAt: Date

    public init(
        id: String,
        email: String? = nil,
        displayName: String? = nil,
        provider: AuthProvider,
        createdAt: Date = .now,
        lastSignInAt: Date = .now
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.provider = provider
        self.createdAt = createdAt
        self.lastSignInAt = lastSignInAt
    }
}
