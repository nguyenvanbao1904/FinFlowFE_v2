import FinFlowCore

/// Creates a new wealth account. Xu ly parse amount string, sign logic (debt accounts luu am),
/// va build request truoc khi gui len repository.
public struct CreateWealthAccountUseCase: Sendable {
    private let repository: any WealthAccountRepositoryProtocol

    public init(repository: any WealthAccountRepositoryProtocol) {
        self.repository = repository
    }

    /// - Parameters:
    ///   - name: Ten tai khoan (se duoc trim whitespace).
    ///   - amountString: So du dang string (e.g. "1.500.000" hoac "-500.000").
    ///   - accountType: Loai tai khoan — neu `debt == true`, balance luon luu am.
    ///   - includeInNetWorth: Tinh vao tong tai san rong.
    public func execute(
        name: String,
        amountString: String,
        accountType: AccountTypeOptionResponse,
        includeInNetWorth: Bool
    ) async throws -> WealthAccountResponse {
        let balance = try Self.resolveBalance(amountString: amountString, isDebt: accountType.debt)
        let request = CreateWealthAccountRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            accountTypeId: accountType.id,
            balance: balance,
            includeInNetWorth: includeInNetWorth
        )
        return try await repository.createWealthAccount(request: request)
    }

    // MARK: - Helpers (internal — shared voi UpdateWealthAccountUseCase)

    /// Parse amount string va ap dung sign rule cho debt accounts.
    /// "1.500.000" → 1500000.0; "-500.000" → -500000.0; debt luon am.
    static func resolveBalance(amountString: String, isDebt: Bool) throws -> Double {
        let t = amountString
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
        let isNegative = t.hasPrefix("-")
        let digits = String(t.dropFirst(isNegative ? 1 : 0).filter { "0123456789".contains($0) })

        guard !digits.isEmpty, let numeric = Double(digits) else {
            throw AppError.validationError("Số dư không hợp lệ")
        }

        let signed = isNegative ? -numeric : numeric
        // Debt account (vay, the tin dung…) luon luu gia tri am
        if isDebt {
            return signed <= 0 ? signed : -signed
        }
        return signed
    }
}
