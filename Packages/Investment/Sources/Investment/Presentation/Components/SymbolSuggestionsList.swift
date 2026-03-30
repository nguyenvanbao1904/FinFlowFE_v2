import FinFlowCore
import SwiftUI

/// Reusable stock symbol suggestion list used by Investment input sheets.
public struct SymbolSuggestionsList: View {
    private let suggestions: [CompanySuggestionResponse]
    private let maxItems: Int
    private let onSelect: (CompanySuggestionResponse) -> Void

    public init(
        suggestions: [CompanySuggestionResponse],
        maxItems: Int = 5,
        onSelect: @escaping (CompanySuggestionResponse) -> Void
    ) {
        self.suggestions = suggestions
        self.maxItems = maxItems
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: .zero) {
            ForEach(suggestions.prefix(maxItems)) { suggestion in
                Button {
                    onSelect(suggestion)
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Text(suggestion.id)
                            .font(AppTypography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .frame(width: 64, alignment: .leading)

                        Text(suggestion.companyName ?? "")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().opacity(0.35)
            }
        }
        .background(AppColors.settingsCardBackground)
        .cornerRadius(CornerRadius.medium)
    }
}

