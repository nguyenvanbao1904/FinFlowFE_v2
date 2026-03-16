import SwiftUI
import Observation
import FinFlowCore

@MainActor
@Observable
public final class AddWealthAccountViewModel {
    public var name = ""
    public var amount = ""
    public var accountTypes: [AccountTypeOptionResponse] = []
    public var selectedAccountType: AccountTypeOptionResponse?
    public var isLoadingTypes = false
    public var isLoading = false
    public var showTypePicker = false
    public var alert: AppErrorAlert?
    public var includeInNetWorth = true

    private let getWealthAccountTypesUseCase: GetWealthAccountTypesUseCase
    private let createWealthAccountUseCase: CreateWealthAccountUseCase
    private let updateWealthAccountUseCase: UpdateWealthAccountUseCase?
    private let sessionManager: any SessionManagerProtocol
    private let existingAccount: WealthAccountResponse?
    private let onSuccess: () -> Void

    public var isEditMode: Bool { existingAccount != nil }

    public init(
        getWealthAccountTypesUseCase: GetWealthAccountTypesUseCase,
        createWealthAccountUseCase: CreateWealthAccountUseCase,
        updateWealthAccountUseCase: UpdateWealthAccountUseCase? = nil,
        sessionManager: any SessionManagerProtocol,
        existingAccount: WealthAccountResponse? = nil,
        onSuccess: @escaping () -> Void = {}
    ) {
        self.getWealthAccountTypesUseCase = getWealthAccountTypesUseCase
        self.createWealthAccountUseCase = createWealthAccountUseCase
        self.updateWealthAccountUseCase = updateWealthAccountUseCase
        self.sessionManager = sessionManager
        self.existingAccount = existingAccount
        self.onSuccess = onSuccess
        if let existing = existingAccount {
            self.name = existing.name
            let absBalance = abs(existing.balance)
            let formatted = CurrencyFormatter.format(absBalance).replacingOccurrences(of: " ₫", with: "")
            self.amount = existing.balance < 0 ? "-" + formatted : formatted
            self.includeInNetWorth = existing.includeInNetWorth
        }
    }

    public var isValid: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let (_, digits) = parseSignedAmount(amount)
        if digits.isEmpty { return false }
        guard Double(digits) != nil else { return false }
        return selectedAccountType != nil
    }

    /// Parses amount string (e.g. "-10.000" or "10.000") into sign and digits; returns (hasLeadingMinus, digitsOnly).
    private func parseSignedAmount(_ value: String) -> (negative: Bool, digits: String) {
        let t = value.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "")
        let neg = t.hasPrefix("-")
        let digits = String(t.dropFirst(neg ? 1 : 0).filter { "0123456789".contains($0) })
        return (neg, digits)
    }

    public func loadAccountTypes() async {
        guard accountTypes.isEmpty, !isLoadingTypes else { return }
        isLoadingTypes = true
        defer { isLoadingTypes = false }
        do {
            let types = try await getWealthAccountTypesUseCase.execute()
            accountTypes = types
            if selectedAccountType == nil {
                if let existing = existingAccount {
                    selectedAccountType = types.first { $0.id == existing.accountType.id }
                }
                if selectedAccountType == nil {
                    selectedAccountType = types.first
                }
            }
        } catch {
            if let appError = error as? AppError, case .unauthorized = appError {
                alert = .authWithAction(message: AppErrorAlert.sessionExpiredMessage) {
                    [sessionManager] in
                    Task { @MainActor in await sessionManager.clearExpiredSession() }
                }
                return
            }
            alert = error.toAppAlert()
        }
    }

    public func save() async {
        guard isValid,
              let type = selectedAccountType else { return }

        let (negative, digits) = parseSignedAmount(amount)
        let numeric = Double(digits) ?? 0
        let signed = negative ? -numeric : numeric
        let balance: Double
        if type.debt {
            balance = signed <= 0 ? signed : -signed
        } else {
            balance = signed
        }

        isLoading = true
        defer { isLoading = false }
        do {
            if let existing = existingAccount, let updateUC = updateWealthAccountUseCase {
                let request = UpdateWealthAccountRequest(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    accountTypeId: type.id,
                    balance: balance,
                    includeInNetWorth: includeInNetWorth
                )
                _ = try await updateUC.execute(id: existing.id, request: request)
            } else {
                let request = CreateWealthAccountRequest(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    accountTypeId: type.id,
                    balance: balance,
                    includeInNetWorth: includeInNetWorth
                )
                _ = try await createWealthAccountUseCase.execute(request: request)
            }
            onSuccess()
        } catch {
            if let appError = error as? AppError, case .unauthorized = appError {
                alert = .authWithAction(message: AppErrorAlert.sessionExpiredMessage) {
                    [sessionManager] in
                    Task { @MainActor in await sessionManager.clearExpiredSession() }
                }
                return
            }
            alert = error.toAppAlert()
        }
    }
}
