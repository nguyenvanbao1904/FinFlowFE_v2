import Foundation

/// Thread-safe actor for handling OTP operations
/// Eliminates duplication of OTP logic across ViewModels
public actor OTPInputHandler {
    
    // MARK: - Error Types
    
    public enum OTPError: LocalizedError {
        case invalidLength
        case invalidFormat
        case sendFailed(String)
        case verifyFailed(String)
        
        public var errorDescription: String? {
            switch self {
            case .invalidLength:
                return "Mã OTP phải có 6 chữ số"
            case .invalidFormat:
                return "Mã OTP chỉ chứa số"
            case .sendFailed(let message):
                return "Gửi OTP thất bại: \(message)"
            case .verifyFailed(let message):
                return "Xác thực OTP thất bại: \(message)"
            }
        }
    }
    
    // MARK: - Properties
    
    private let repository: any OTPRepositoryProtocol
    
    // MARK: - Initialization
    
    public init(repository: any OTPRepositoryProtocol) {
        self.repository = repository
    }
    
    // MARK: - Validation
    
    /// Validates OTP code format and length
    /// - Parameter code: OTP code to validate
    /// - Returns: true if valid (6 digits), false otherwise
    public func validate(_ code: String) -> Bool {
        // Must be exactly 6 characters
        guard code.count == 6 else {
            return false
        }
        
        // Must be all digits
        let digitsOnly = CharacterSet.decimalDigits
        return code.unicodeScalars.allSatisfy { digitsOnly.contains($0) }
    }
    
    // MARK: - Send OTP
    
    /// Sends OTP to the specified email for given purpose
    /// - Parameters:
    ///   - email: Email address to send OTP to
    ///   - purpose: Purpose of the OTP (register, resetPassword, deleteAccount, etc.)
    /// - Throws: OTPError if sending fails
    public func sendOTP(to email: String, purpose: OtpPurpose) async throws {
        Logger.info("📧 Sending OTP to \(email) for purpose: \(purpose.rawValue)", category: "OTP")
        
        do {
            try await repository.sendOtp(email: email, purpose: purpose)
            Logger.info("✅ OTP sent successfully to \(email)", category: "OTP")
        } catch {
            Logger.error("❌ Failed to send OTP: \(error)", category: "OTP")
            throw OTPError.sendFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Verify OTP
    
    /// Verifies OTP code for the specified email and purpose
    /// - Parameters:
    ///   - email: Email address associated with the OTP
    ///   - code: OTP code to verify
    ///   - purpose: Purpose of the OTP
    /// - Returns: VerifyOtpResponse containing verification token
    /// - Throws: OTPError if validation or verification fails
    public func verifyOTP(
        email: String,
        code: String,
        purpose: OtpPurpose
    ) async throws -> VerifyOtpResponse {
        // Validate format first
        guard validate(code) else {
            Logger.warning("⚠️ Invalid OTP format: \(code.count) chars", category: "OTP")
            throw OTPError.invalidLength
        }
        
        Logger.info("🔐 Verifying OTP for \(email), purpose: \(purpose.rawValue)", category: "OTP")
        
        do {
            let response = try await repository.verifyOtp(
                email: email,
                otp: code,
                purpose: purpose
            )
            Logger.info("✅ OTP verified successfully for \(email)", category: "OTP")
            return response
        } catch {
            Logger.error("❌ OTP verification failed: \(error)", category: "OTP")
            throw OTPError.verifyFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Utility
    
    /// Formats OTP code by removing non-digit characters
    /// - Parameter input: Raw input string
    /// - Returns: Cleaned string containing only digits, max 6 chars
    public func formatInput(_ input: String) -> String {
        let digitsOnly = input.filter { $0.isNumber }
        return String(digitsOnly.prefix(6))
    }
}
