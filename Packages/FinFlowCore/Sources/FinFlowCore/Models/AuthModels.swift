import Foundation

// MARK: - DEPRECATED - For Backward Compatibility Only


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
    public let refreshTokenExpiresIn: Int?
    public let isReactivated: Bool?

    public init(
        email: String, token: String, refreshToken: String?, type: String, username: String,
        expiresIn: Int?, refreshTokenExpiresIn: Int? = nil, isReactivated: Bool? = nil
    ) {
        self.email = email
        self.token = token
        self.refreshToken = refreshToken
        self.type = type
        self.username = username
        self.expiresIn = expiresIn
        self.refreshTokenExpiresIn = refreshTokenExpiresIn
        self.isReactivated = isReactivated
    }

    public var authenticated: Bool { !token.isEmpty }
}

public struct RefreshTokenRequest: Codable, Sendable {
    public let refreshToken: String
    public init(refreshToken: String) { self.refreshToken = refreshToken }
}

public struct RefreshTokenResponse: Codable, Sendable {
    public let token: String
    public let refreshToken: String?
    public let type: String
    public let expiresIn: Int?
    public let refreshTokenExpiresIn: Int?

    public init(
        token: String, refreshToken: String?, type: String, expiresIn: Int?,
        refreshTokenExpiresIn: Int? = nil
    ) {
        self.token = token
        self.refreshToken = refreshToken
        self.type = type
        self.expiresIn = expiresIn
        self.refreshTokenExpiresIn = refreshTokenExpiresIn
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
    public init(idToken: String) { self.idToken = idToken }
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

public struct ResetPasswordRequest: Codable, Sendable {
    public let password: String
    public let confirmPassword: String
    public init(password: String, confirmPassword: String) {
        self.password = password
        self.confirmPassword = confirmPassword
    }
}

public struct SendOtpRequest: Codable, Sendable {
    public let email: String
    public let purpose: OtpPurpose
    public init(email: String, purpose: OtpPurpose) {
        self.email = email
        self.purpose = purpose
    }
}

public struct VerifyOtpRequest: Codable, Sendable {
    public let email: String
    public let otp: String
    public let purpose: OtpPurpose
    public init(email: String, otp: String, purpose: OtpPurpose) {
        self.email = email
        self.otp = otp
        self.purpose = purpose
    }
}

public struct CheckUserExistenceRequest: Codable, Sendable {
    public let email: String?
    public let username: String?
    public init(email: String? = nil, username: String? = nil) {
        self.email = email
        self.username = username
    }
}

public struct ChangePasswordRequest: Codable, Sendable {
    public let oldPassword: String?
    public let newPassword: String
    public init(oldPassword: String?, newPassword: String) {
        self.oldPassword = oldPassword
        self.newPassword = newPassword
    }
}

public struct CheckUserExistenceResponse: Codable, Sendable {
    public let exists: Bool
    public let isActive: Bool?  // nil if user doesn't exist
    public let hasPassword: Bool?  // nil if user doesn't exist
    public let isDeleted: Bool?  // true if deletedAt != null
}

public struct DeleteAccountRequest: Codable, Sendable {
    public let password: String?
    public init(password: String?) {
        self.password = password
    }
}
