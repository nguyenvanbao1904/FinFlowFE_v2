import FinFlowCore
import SwiftUI

public struct CategoryListView: View {
    private enum ActiveSheet: String, Identifiable {
        case addCategory
        var id: String { rawValue }
    }

    @Bindable var viewModel: CategoryListViewModel
    @State private var activeSheet: ActiveSheet?
    @State private var categoryToEdit: CategoryResponse?
    @State private var categoryToDelete: CategoryResponse?
    @State private var showDeleteConfirmation = false

    public init(viewModel: CategoryListViewModel) {
        self.viewModel = viewModel
    }

    private var incomeCategories: [CategoryResponse] {
        viewModel.categories.filter { $0.type == .income }
    }

    private var expenseCategories: [CategoryResponse] {
        viewModel.categories.filter { $0.type == .expense }
    }

    public var body: some View {
        Group {
            if viewModel.isLoading && viewModel.categories.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.loadError != nil {
                ContentUnavailableView(
                    "Không thể tải danh mục",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Vui lòng thử lại sau.")
                )
                .listRowBackground(Color.clear)
            } else if viewModel.categories.isEmpty {
                EmptyStateView(
                    icon: "tag",
                    title: "Chưa có danh mục",
                    subtitle:
                        "Danh mục hệ thống sẽ hiển thị sau khi đồng bộ. Bạn cũng có thể thêm danh mục riêng.",
                    buttonTitle: "Thêm danh mục",
                    action: { activeSheet = .addCategory }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.appBackground)
            } else {
                List {
                    if !incomeCategories.isEmpty {
                        Section("Thu nhập") {
                            ForEach(incomeCategories) { category in
                                categoryRow(category)
                            }
                        }
                    }

                    if !expenseCategories.isEmpty {
                        Section("Chi tiêu") {
                            ForEach(expenseCategories) { category in
                                categoryRow(category)
                            }
                        }
                    }
                }
            }
        }
        .background(AppColors.appBackground)
        .navigationTitle("Danh mục")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    activeSheet = .addCategory
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.primary)
                }
                .accessibilityLabel("Thêm danh mục")
            }
        }
        .task {
            await viewModel.loadCategories()
        }
        .refreshable {
            await viewModel.loadCategories(force: true)
        }
        // swiftlint:disable:next no_direct_sheet_or_cover
        .sheet(item: $activeSheet) { _ in
            NavigationStack {
                AddEditCategoryView(
                    viewModel: viewModel,
                    categoryToEdit: nil,
                    onDismiss: { activeSheet = nil }
                )
            }
        }
        // swiftlint:disable:next no_direct_sheet_or_cover
        .sheet(item: $categoryToEdit) { category in
            NavigationStack {
                AddEditCategoryView(
                    viewModel: viewModel,
                    categoryToEdit: category,
                    onDismiss: { categoryToEdit = nil }
                )
            }
        }
        .alertHandler($viewModel.alert)
        .alert("Xác nhận xóa", isPresented: $showDeleteConfirmation) {
            Button("Hủy", role: .cancel) {
                categoryToDelete = nil
            }
            Button("Xóa", role: .destructive) {
                if let category = categoryToDelete {
                    Task { await viewModel.deleteCategory(id: category.id) }
                }
                categoryToDelete = nil
            }
        } message: {
            Text("Bạn có chắc chắn muốn xóa danh mục này?")
        }
    }

    private func categoryRow(_ category: CategoryResponse) -> some View {
        Button {
            guard !category.systemCategory else { return }
            categoryToEdit = category
        } label: {
            IconTitleTrailingRow(
                icon: category.icon ?? "tag",
                color: Color(hex: category.color),
                title: category.name,
                subtitle: nil
            ) {
                if !category.systemCategory {
                    Image(systemName: "chevron.right")
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(category.systemCategory)
        .opacity(category.systemCategory ? 0.6 : 1.0)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !category.systemCategory {
                Button(role: .destructive) {
                    categoryToDelete = category
                    showDeleteConfirmation = true
                } label: {
                    Label("Xóa", systemImage: "trash")
                }
            }
        }
    }
}
