import Foundation

// MARK: - Authentication Models

public struct LoginRequest: Codable, Sendable {
    public let username: String
    public let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

public struct LoginResponse: Codable, Sendable {
    public let email: String
    public let token: String
    public let refreshToken: String?
    public let type: String
    public let username: String
    public let expiresIn: Int?

    public init(
        email: String, token: String, refreshToken: String?, type: String, username: String,
        expiresIn: Int?
    ) {
        self.email = email
        self.token = token
        self.refreshToken = refreshToken
        self.type = type
        self.username = username
        self.expiresIn = expiresIn
    }

    public var authenticated: Bool {
        return !token.isEmpty
    }
}

public struct UserProfile: Codable, Sendable, Hashable {
    public let id: String
    public let username: String
    public let email: String
    public let firstName: String?
    public let lastName: String?
    public let dob: String?
    public let roles: [String]

    public init(
        id: String, username: String, email: String, firstName: String?, lastName: String?,
        dob: String?, roles: [String]
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.dob = dob
        self.roles = roles
    }
}

public struct RefreshTokenRequest: Codable, Sendable {
    public let refreshToken: String

    public init(refreshToken: String) {
        self.refreshToken = refreshToken
    }
}

public struct RefreshTokenResponse: Codable, Sendable {
    public let token: String
    public let refreshToken: String?
    public let type: String
    public let expiresIn: Int?

    public init(token: String, refreshToken: String?, type: String, expiresIn: Int?) {
        self.token = token
        self.refreshToken = refreshToken
        self.type = type
        self.expiresIn = expiresIn
    }
}

public struct UpdateProfileRequest: Codable, Sendable {
    public let firstName: String
    public let lastName: String
    public let dob: String

    public init(firstName: String, lastName: String, dob: String) {
        self.firstName = firstName
        self.lastName = lastName
        self.dob = dob
    }
}

public struct GoogleLoginRequest: Codable, Sendable {
    public let idToken: String

    public init(idToken: String) {
        self.idToken = idToken
    }
}

public struct RegisterRequest: Codable, Sendable {
    public let username: String
    public let email: String
    public let password: String
    public let firstName: String?
    public let lastName: String?
    public let dob: String?

    public init(
        username: String, email: String, password: String, firstName: String?, lastName: String?,
        dob: String?
    ) {
        self.username = username
        self.email = email
        self.password = password
        self.firstName = firstName
        self.lastName = lastName
        self.dob = dob
    }
}

public struct RegisterResponse: Codable, Sendable {
    public let message: String
}

public struct VerifyOtpResponse: Codable, Sendable {
    public let message: String
    public let registrationToken: String
}
