import FinFlowCore
import SwiftUI

struct RenamePortfolioSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var isSaving = false

    let onRename: @Sendable (String) async -> Void

    init(currentName: String, onRename: @escaping @Sendable (String) async -> Void) {
        _name = State(initialValue: currentName)
        self.onRename = onRename
    }

    var body: some View {
        SheetContainer(
            title: "Đổi tên danh mục",
            detents: [.medium],
            allowDismissal: !isSaving
        ) {
            VStack(spacing: Spacing.lg) {
                GlassField(
                    text: $name,
                    placeholder: "Tên danh mục mới",
                    icon: "pencil"
                )

                Spacer(minLength: 0)

                Button {
                    Task { @MainActor in await submit() }
                } label: {
                    Text("Lưu")
                }
                .primaryButton(isLoading: isSaving)
                .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(AppColors.appBackground)
        }
    }

    private func submit() async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSaving = true
        defer { isSaving = false }

        await onRename(trimmed)
        dismiss()
    }
}
