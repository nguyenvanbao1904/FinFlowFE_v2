import FinFlowCore
import SwiftUI

/// Main view for the Wealth tab: single scrollable list of accounts grouped by category.
public struct WealthListView: View {
    private enum ActiveSheet: String, Identifiable {
        case addAccount
        var id: String { rawValue }
    }

    @Bindable var viewModel: WealthListViewModel

    @State private var activeSheet: ActiveSheet?
    @State private var accountToEdit: WealthAccountResponse?
    @State private var accountToDelete: WealthAccountResponse?
    @State private var showDeleteConfirmation = false

    public init(viewModel: WealthListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        List {
            // Hero card
            Section {
                Group {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(Spacing.lg)
                    } else {
                        FinancialHeroCard(
                            title: "Tài sản ròng",
                            mainAmount: CurrencyFormatter.format(viewModel.netWorth),
                            subtitle: "Tài sản + Tiêu sản − Nợ"
                        )
                    }
                }
                .listRowInsets(
                    EdgeInsets(top: Spacing.sm, leading: .zero, bottom: Spacing.sm, trailing: .zero)
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if viewModel.accounts.isEmpty && !viewModel.isLoading {
                Section {
                    EmptyStateView(
                        icon: "creditcard",
                        title: "Chưa có tài khoản nào",
                        subtitle: "Thêm ví hoặc tài khoản để bắt đầu theo dõi tài sản",
                        buttonTitle: "Thêm tài khoản",
                        action: { activeSheet = .addAccount }
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } else {
                ForEach(viewModel.groupedAccounts, id: \.header) { group in
                    Section(group.header) {
                        ForEach(group.accounts) { account in
                            Button {
                                accountToEdit = account
                            } label: {
                                AccountRowView(account: account)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    accountToDelete = account
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Xóa", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button {
                                    accountToEdit = account
                                } label: {
                                    Label("Sửa", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    accountToDelete = account
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Xóa", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: Spacing.xl)
        }
        .background(AppColors.appBackground)
        .navigationTitle("Tài sản")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    activeSheet = .addAccount
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.primary)
                }
                .accessibilityLabel("Thêm tài khoản")
            }
        }
        .task { await viewModel.loadData() }
        .refreshable { await viewModel.loadData(force: true) }
        .onReceive(NotificationCenter.default.publisher(for: .wealthAccountDidSave)) { _ in
            Task { await viewModel.loadData(force: true) }
        }
        .alertHandler($viewModel.loadError)
        // swiftlint:disable:next no_direct_sheet_or_cover
        .sheet(item: $activeSheet) { _ in
            NavigationStack {
                AddWealthAccountView(
                    viewModel: AddWealthAccountViewModel(
                        getWealthAccountTypesUseCase: viewModel.getWealthAccountTypesUseCase,
                        createWealthAccountUseCase: viewModel.createWealthAccountUseCase,
                        sessionManager: viewModel.sessionManager,
                        onSuccess: {
                            activeSheet = nil
                            Task { await viewModel.loadData(force: true) }
                        }
                    )
                )
            }
        }
        // swiftlint:disable:next no_direct_sheet_or_cover
        .sheet(item: $accountToEdit) { account in
            NavigationStack {
                AddWealthAccountView(
                    viewModel: AddWealthAccountViewModel(
                        getWealthAccountTypesUseCase: viewModel.getWealthAccountTypesUseCase,
                        createWealthAccountUseCase: viewModel.createWealthAccountUseCase,
                        updateWealthAccountUseCase: viewModel.updateWealthAccountUseCase,
                        sessionManager: viewModel.sessionManager,
                        existingAccount: account,
                        onSuccess: {
                            accountToEdit = nil
                            Task { await viewModel.loadData(force: true) }
                        }
                    )
                )
            }
        }
        .alert("Xác nhận xóa", isPresented: $showDeleteConfirmation) {
            Button("Hủy", role: .cancel) {
                accountToDelete = nil
            }
            Button("Xóa", role: .destructive) {
                if let account = accountToDelete {
                    Task { await viewModel.deleteAccount(account) }
                }
                accountToDelete = nil
            }
        } message: {
            Text("Bạn có chắc chắn muốn xóa tài khoản này? Giao dịch liên quan có thể bị ảnh hưởng.")
        }
    }
}

private struct AccountRowView: View {
    let account: WealthAccountResponse

    var body: some View {
        IconTitleTrailingRow(
            icon: account.accountType.icon,
            color: Color(hex: account.accountType.color),
            title: account.name,
            subtitle: nil,
            trailing: {
                BalanceLabel(balance: account.balance)
                    .font(AppTypography.headline)
            }
        )
    }
}
