import Foundation

public enum SessionState: Equatable, Codable {
    case guest
    case authenticated(AuthUser)
    case signedOut

    private enum CodingKeys: String, CodingKey {
        case kind
        case user
    }

    private enum Kind: String, Codable {
        case guest
        case authenticated
        case signedOut
    }

    public var user: AuthUser? {
        switch self {
        case .authenticated(let user):
            return user
        case .guest, .signedOut:
            return nil
        }
    }

    public var isAuthenticated: Bool {
        if case .authenticated = self {
            return true
        }
        return false
    }

    public var isGuest: Bool {
        if case .guest = self {
            return true
        }
        return false
    }

    public var isSignedOut: Bool {
        if case .signedOut = self {
            return true
        }
        return false
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .guest:
            self = .guest
        case .signedOut:
            self = .signedOut
        case .authenticated:
            let user = try container.decode(AuthUser.self, forKey: .user)
            self = .authenticated(user)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .guest:
            try container.encode(Kind.guest, forKey: .kind)
        case .signedOut:
            try container.encode(Kind.signedOut, forKey: .kind)
        case .authenticated(let user):
            try container.encode(Kind.authenticated, forKey: .kind)
            try container.encode(user, forKey: .user)
        }
    }
}
