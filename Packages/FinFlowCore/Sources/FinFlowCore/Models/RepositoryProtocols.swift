import Foundation

// MARK: - Segregated Repository Protocols (Interface Segregation Principle)

/// Handles authentication operations (login, register, logout, token refresh)
public protocol AuthenticationRepositoryProtocol: Sendable {
    func login(req: LoginRequest) async throws -> LoginResponse
    func loginGoogle(idToken: String) async throws -> LoginResponse
    func register(req: RegisterRequest, token: String) async throws
    func logout() async throws
    func refreshToken() async throws -> RefreshTokenResponse
    /// Refresh token without logout/clear on failure (for silent flows)
    func refreshTokenSilent() async throws -> RefreshTokenResponse
}

/// Handles user profile operations (get, update)
public protocol ProfileRepositoryProtocol: Sendable {
    func getMyProfile() async throws -> UserProfile
    func updateProfile(request: UpdateProfileRequest) async throws -> UserProfile
}

/// Handles OTP operations (send, verify)
public protocol OTPRepositoryProtocol: Sendable {
    func sendOtp(email: String, purpose: OtpPurpose) async throws
    func verifyOtp(email: String, otp: String, purpose: OtpPurpose) async throws
        -> VerifyOtpResponse
}

/// Handles account management (password, biometric, deletion, existence check)
public protocol AccountRepositoryProtocol: Sendable {
    func checkUserExistence(email: String?, username: String?) async throws
        -> CheckUserExistenceResponse
    func changePassword(req: ChangePasswordRequest) async throws
    func resetPassword(req: ResetPasswordRequest, token: String) async throws
    func toggleBiometric(enabled: Bool) async throws
    func deleteAccount(password: String?, token: String) async throws
}

// MARK: - Transaction Repository Protocol

/// Handles transaction operations (add, list, summary, categories)
public protocol TransactionRepositoryProtocol: Sendable {
    func getCategories() async throws -> [CategoryResponse]
    func addTransaction(request: AddTransactionRequest) async throws -> TransactionResponse
    func updateTransaction(id: String, request: AddTransactionRequest) async throws
        -> TransactionResponse
    func getTransactions(page: Int, size: Int, startDate: Date?, endDate: Date?, keyword: String?)
        async throws -> PaginatedResponse<TransactionResponse>
    func getTransactionSummary() async throws -> TransactionSummaryResponse
    func analyzeTransaction(request: AnalyzeTransactionRequest) async throws
        -> AnalyzeTransactionResponse
    func getChart(range: ChartRange, referenceDate: Date) async throws -> TransactionChartResponse
    func deleteTransaction(id: String) async throws
}

// MARK: - Composite Protocol (Backward Compatibility)

/// Composite protocol that combines all repository protocols
/// This maintains backward compatibility while allowing gradual migration to segregated protocols
public protocol AuthRepositoryProtocol:
    AuthenticationRepositoryProtocol,
    ProfileRepositoryProtocol,
    OTPRepositoryProtocol,
    AccountRepositoryProtocol,
    Sendable {
    // All methods inherited from composed protocols
}
