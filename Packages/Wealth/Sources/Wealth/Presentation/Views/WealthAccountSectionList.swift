import FinFlowCore
import SwiftUI

struct AccountSectionConfig {
    let sectionHeader: String
    let title: String
    let subtitle: String
    let amount: Double
}

struct AccountSectionActions {
    let onEdit: (WealthAccountResponse) -> Void
    let onDelete: (WealthAccountResponse) -> Void
    let onAdd: () -> Void
}

struct WealthAccountSectionList: View {
    let config: AccountSectionConfig
    let items: [WealthAccountResponse]
    let isLoading: Bool
    let actions: AccountSectionActions

    var body: some View {
        List {
            Section {
                Group {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(Spacing.lg)
                    } else {
                        FinancialHeroCard(
                            title: config.title,
                            mainAmount: CurrencyFormatter.format(config.amount),
                            subtitle: config.subtitle
                        )
                    }
                }
                .listRowInsets(
                    EdgeInsets(top: Spacing.sm, leading: .zero, bottom: Spacing.sm, trailing: .zero)
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                if items.isEmpty && !isLoading {
                    EmptyStateView(
                        icon: "creditcard",
                        title: "Chưa có tài khoản nào",
                        subtitle: "Thêm ví hoặc tài khoản để bắt đầu theo dõi tài sản",
                        buttonTitle: "Thêm tài khoản",
                        action: actions.onAdd
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(items) { account in
                        Button {
                            actions.onEdit(account)
                        } label: {
                            AccountRowView(account: account)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                actions.onDelete(account)
                            } label: {
                                Label("Xóa", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button {
                                actions.onEdit(account)
                            } label: {
                                Label("Sửa", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                actions.onDelete(account)
                            } label: {
                                Label("Xóa", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                Text(config.sectionHeader)
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: Spacing.xl)
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
