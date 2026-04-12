import Foundation

// MARK: - Domain Models (Shared across app)

/// User Profile - Domain Entity
/// This is the core user representation used throughout the app
public struct UserProfile: Codable, Sendable, Hashable {
    public let id: String
    public let username: String
    public let email: String
    public let firstName: String?
    public let lastName: String?
    public let dob: String?
    public let isBiometricEnabled: Bool?
    public let hasPassword: Bool
    public let roles: [String]

    public init(
        id: String, username: String, email: String, firstName: String?, lastName: String?,
        dob: String?, isBiometricEnabled: Bool? = nil, hasPassword: Bool? = nil, roles: [String]
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.dob = dob
        self.isBiometricEnabled = isBiometricEnabled
        self.hasPassword = hasPassword ?? false
        self.roles = roles
    }
    public var fullName: String {
        [firstName, lastName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    public var initials: String {
        let first = firstName?.first.map { String($0) } ?? ""
        let last = lastName?.first.map { String($0) } ?? ""
        if first.isEmpty && last.isEmpty { return "?" }
        return (first + last).uppercased()
    }
    
    // Helper method to create a copy with modified properties
    public func copy(
        firstName: String? = nil,
        lastName: String? = nil,
        dob: String? = nil,
        isBiometricEnabled: Bool? = nil,
        hasPassword: Bool? = nil
    ) -> UserProfile {
        return UserProfile(
            id: self.id,
            username: self.username,
            email: self.email,
            firstName: firstName ?? self.firstName,
            lastName: lastName ?? self.lastName,
            dob: dob ?? self.dob,
            isBiometricEnabled: isBiometricEnabled ?? self.isBiometricEnabled,
            hasPassword: hasPassword ?? self.hasPassword,
            roles: self.roles
        )
    }
}

/// OTP Purpose - Domain Enum
public enum OtpPurpose: String, Codable, Sendable {
    case register = "REGISTER"
    case resetPassword = "RESET_PASSWORD"
    case deleteAccount = "DELETE_ACCOUNT"
    case resetPin = "RESET_PIN"
}
