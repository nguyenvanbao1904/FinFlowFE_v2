import FinFlowCore
import Foundation

// Re-export models from FinFlowCore for backward compatibility
public typealias LoginRequest = FinFlowCore.LoginRequest
public typealias LoginResponse = FinFlowCore.LoginResponse
public typealias UserProfile = FinFlowCore.UserProfile
public typealias RefreshTokenRequest = FinFlowCore.RefreshTokenRequest
public typealias RefreshTokenResponse = FinFlowCore.RefreshTokenResponse

public struct GoogleLoginRequest: Encodable, Sendable {
    public let idToken: String
    
    public init(idToken: String) {
        self.idToken = idToken
    }
}
