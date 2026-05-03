import FinFlowCore
import Observation

@MainActor
@Observable
public final class WealthListViewModel {
    // MARK: - State
    public var accounts: [WealthAccountResponse] = []
    public var isLoading = false
    public var loadError: AppErrorAlert?

    // MARK: - Dependencies
    let getWealthAccountsUseCase: GetWealthAccountsUseCase
    let getWealthAccountTypesUseCase: GetWealthAccountTypesUseCase
    let createWealthAccountUseCase: CreateWealthAccountUseCase
    let updateWealthAccountUseCase: UpdateWealthAccountUseCase
    let deleteWealthAccountUseCase: DeleteWealthAccountUseCase
    let sessionManager: any SessionManagerProtocol

    @ObservationIgnored
    private var hasRequestedInitialLoad = false

    public init(
        getWealthAccountsUseCase: GetWealthAccountsUseCase,
        getWealthAccountTypesUseCase: GetWealthAccountTypesUseCase,
        createWealthAccountUseCase: CreateWealthAccountUseCase,
        updateWealthAccountUseCase: UpdateWealthAccountUseCase,
        deleteWealthAccountUseCase: DeleteWealthAccountUseCase,
        sessionManager: any SessionManagerProtocol
    ) {
        self.getWealthAccountsUseCase = getWealthAccountsUseCase
        self.getWealthAccountTypesUseCase = getWealthAccountTypesUseCase
        self.createWealthAccountUseCase = createWealthAccountUseCase
        self.updateWealthAccountUseCase = updateWealthAccountUseCase
        self.deleteWealthAccountUseCase = deleteWealthAccountUseCase
        self.sessionManager = sessionManager
    }

    // MARK: - Computed

    public var netWorth: Double {
        accounts.filter { $0.includeInNetWorth }.reduce(0) { $0 + $1.balance }
    }

    /// Accounts grouped by `group` field, ordered: LIQUID → INVESTMENT → ASSET → DEBT.
    /// Unknown groups fall back to raw key as header and appear last.
    public var groupedAccounts: [(header: String, accounts: [WealthAccountResponse])] {
        let grouped = Dictionary(grouping: accounts, by: { $0.accountType.group })
        return grouped
            .sorted { (Self.groupOrder[$0.key] ?? 99) < (Self.groupOrder[$1.key] ?? 99) }
            .map { (header: Self.groupDisplayNames[$0.key] ?? $0.key, accounts: $0.value) }
    }

    private static let groupOrder = ["LIQUID": 0, "INVESTMENT": 1, "ASSET": 2, "DEBT": 3]
    private static let groupDisplayNames = [
        "LIQUID": "Thanh khoản",
        "INVESTMENT": "Đầu tư",
        "ASSET": "Tài sản",
        "DEBT": "Nợ",
    ]

    // MARK: - Actions

    public func loadData(force: Bool = false) async {
        if !force {
            if hasRequestedInitialLoad { return }
            hasRequestedInitialLoad = true
        }

        if isLoading { return }

        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            accounts = try await getWealthAccountsUseCase.execute()
        } catch {
            loadError = error.toHandledAlert(sessionManager: sessionManager)
        }
    }

    public func deleteAccount(_ account: WealthAccountResponse) async {
        do {
            try await deleteWealthAccountUseCase.execute(id: account.id)
            await loadData(force: true)
        } catch {
            loadError = error.toHandledAlert(sessionManager: sessionManager)
        }
    }
}
