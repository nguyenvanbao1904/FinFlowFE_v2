import FinFlowCore
import SwiftUI

public struct AddEditCategoryView: View {
    @Bindable var viewModel: CategoryListViewModel
    let categoryToEdit: CategoryResponse?
    let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var type: TransactionType = .expense
    @State private var icon: String = ""
    @State private var selectedColor: Color = AppColors.primary
    @State private var isSaving = false

    private var isEditMode: Bool { categoryToEdit != nil }

    /// Curated SF Symbols for category icon (native Picker, no custom UI).
    private static let iconSymbolNames: [String] = [
        "banknote", "banknote.fill", "gift", "gift.fill",
        "chart.line.uptrend.xyaxis", "chart.bar.fill", "creditcard", "creditcard.fill",
        "fork.knife", "car", "car.fill", "bus", "bus.fill",
        "bag", "bag.fill", "cart", "cart.fill",
        "heart", "heart.fill", "cross.case", "cross.case.fill",
        "house", "house.fill", "book", "book.fill",
        "doc.text", "doc.text.fill", "tag", "tag.fill",
        "star", "star.fill", "briefcase", "briefcase.fill",
        "wrench.and.screwdriver", "wrench.and.screwdriver.fill",
        "tv", "tv.fill", "gamecontroller", "gamecontroller.fill",
        "ellipsis.circle", "ellipsis.circle.fill"
    ]

    public init(
        viewModel: CategoryListViewModel,
        categoryToEdit: CategoryResponse?,
        onDismiss: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.categoryToEdit = categoryToEdit
        self.onDismiss = onDismiss
    }

    public var body: some View {
        Form {
            Section {
                TextField("Tên danh mục", text: $name)
                    .textInputAutocapitalization(.words)
            } header: {
                Text("Tên")
            } footer: {
                Text("Ví dụ: Ăn sáng, Đi chợ, Lương tháng")
            }

            if !isEditMode {
                Section {
                    Picker("Loại", selection: $type) {
                        Text("Thu nhập").tag(TransactionType.income)
                        Text("Chi tiêu").tag(TransactionType.expense)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Loại danh mục")
                }
            }

            Section {
                Picker("Icon", selection: $icon) {
                    Text("Mặc định").tag("")
                    ForEach(Self.iconSymbolNames, id: \.self) { name in
                        Label(name, systemImage: name).tag(name)
                    }
                }
                .pickerStyle(.navigationLink)
                ColorPicker("Màu", selection: $selectedColor, supportsOpacity: false)
            } header: {
                Text("Tùy chọn")
            } footer: {
                Text("Để trống icon sẽ dùng mặc định.")
            }
        }
        .navigationTitle(isEditMode ? "Sửa danh mục" : "Thêm danh mục")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Hủy") {
                    onDismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Lưu") {
                    Task { await save() }
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }
        }
        .onAppear {
            if let cat = categoryToEdit {
                name = cat.name
                icon = cat.icon ?? ""
                if !cat.color.isEmpty {
                    selectedColor = Color(hex: cat.color)
                }
            }
        }
        .alertHandler($viewModel.alert)
    }

    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }

        let colorHex = selectedColor.toHex
        let success: Bool
        if let cat = categoryToEdit {
            success = await viewModel.updateCategory(
                id: cat.id,
                name: trimmedName,
                icon: icon.isEmpty ? nil : icon,
                color: colorHex
            )
        } else {
            success = await viewModel.createCategory(
                name: trimmedName,
                type: type,
                icon: icon.isEmpty ? nil : icon,
                color: colorHex
            )
        }
        if success {
            onDismiss()
        }
    }
}
