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

    /// Hydrate from `categoryToEdit` only when this identity changes — not on every `onAppear` / `.task` re-run
    /// (e.g. after popping the icon `Picker` navigation). `add` must stay stable across nil `id`, unlike `.task(id: nil)`.
    @State private var lastHydratedFormIdentity: String?

    private var isEditMode: Bool { categoryToEdit != nil }

    private var formIdentityKey: String {
        if let id = categoryToEdit?.id {
            return "edit:\(id)"
        }
        return "add"
    }

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

    private static let iconSymbolNamesSet: Set<String> = Set(iconSymbolNames)

    /// Icons not in the picker list cannot be represented as a selection; map to default row.
    private static func sanitizedIconForPicker(_ raw: String?) -> String {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return "" }
        return iconSymbolNamesSet.contains(trimmed) ? trimmed : ""
    }

    private func applyModelToForm() {
        if let cat = categoryToEdit {
            name = cat.name
            icon = Self.sanitizedIconForPicker(cat.icon)
            if !cat.color.isEmpty {
                selectedColor = Color(hex: cat.color)
            }
        } else {
            name = ""
            type = .expense
            icon = ""
            selectedColor = AppColors.primary
        }
    }

    private func hydrateFromModelIfIdentityChanged() {
        let key = formIdentityKey
        if lastHydratedFormIdentity == key { return }
        lastHydratedFormIdentity = key
        applyModelToForm()
    }

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
                // `.navigationLink` pushes a child; popping back often re-triggers `onAppear` and breaks selection.
                // Menu keeps selection on-screen without a separate navigation destination.
                .pickerStyle(.menu)
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
            hydrateFromModelIfIdentityChanged()
        }
        .onChange(of: categoryToEdit?.id) { _, _ in
            hydrateFromModelIfIdentityChanged()
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
