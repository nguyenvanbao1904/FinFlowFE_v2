import FinFlowCore
import SwiftUI

public struct CreatePortfolioSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    let onCreate: @Sendable (String) async -> Void

    public init(onCreate: @escaping @Sendable (String) async -> Void) {
        self.onCreate = onCreate
    }

    public var body: some View {
        SheetContainer(
            title: "Tạo danh mục",
            detents: [.medium],
            allowDismissal: !isSaving
        ) {
            VStack(spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Thông tin danh mục")
                        .font(AppTypography.subheadline)
                        .foregroundStyle(.secondary)

                    GlassField(
                        text: $name,
                        placeholder: "Tên danh mục (VD: Tích sản hưu trí)",
                        icon: "briefcase.fill"
                    )

                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    Task { @MainActor in
                        await submit()
                    }
                } label: {
                    Text("Tạo")
                }
                .primaryButton(isLoading: isSaving)
                .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(AppColors.appBackground)
        }
    }

    private func submit() async {
        errorMessage = nil
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Tên danh mục không được để trống."
            return
        }

        isSaving = true
        defer { isSaving = false }

        await onCreate(trimmed)
        dismiss()
    }
}
