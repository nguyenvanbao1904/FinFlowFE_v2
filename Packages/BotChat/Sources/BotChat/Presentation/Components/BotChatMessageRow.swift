import FinFlowCore
import SwiftUI

public struct FinFlowBotChatMessageRow: View {
    let message: FinFlowBotChatMessage

    private var isBot: Bool {
        message.sender == .bot
    }

    private var citationSummary: String? {
        let normalized = message.citations
            .compactMap { citation -> String? in
                let title = citation.sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return nil }
                if let page = citation.pageNumber {
                    return "\(title) · tr.\(page)"
                }
                return title
            }

        guard !normalized.isEmpty else { return nil }
        let head = normalized.prefix(2).joined(separator: " • ")
        let tailCount = max(0, normalized.count - 2)
        let suffix = tailCount > 0 ? " +\(tailCount)" : ""
        return "Nguồn: \(head)\(suffix)"
    }

    public init(message: FinFlowBotChatMessage) {
        self.message = message
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.xs) {
            if isBot {
                Image(systemName: "sparkles")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.accent)
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                    .background(AppColors.primary.opacity(OpacityLevel.ultraLight))
                    .clipShape(Circle())
                    .accessibilityHidden(true)
            } else {
                Spacer(minLength: Spacing.touchTarget)
            }

            VStack(alignment: isBot ? .leading : .trailing, spacing: BorderWidth.hairline) {
                Text(message.text)
                    .font(AppTypography.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Text(message.sentAt.formatted(date: .omitted, time: .shortened))
                    .font(AppTypography.caption2)
                    .foregroundStyle(.secondary)

                if let citationSummary {
                    Text(citationSummary)
                        .font(AppTypography.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .frame(maxWidth: .infinity, alignment: isBot ? .leading : .trailing)
            .background(isBot ? AppColors.cardBackground : AppColors.primary.opacity(OpacityLevel.light))
            .clipShape(.rect(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(
                        isBot
                            ? AppColors.inputBorderDefault.opacity(OpacityLevel.medium)
                            : AppColors.primary.opacity(OpacityLevel.medium),
                        lineWidth: BorderWidth.hairline
                    )
            )
            .frame(maxWidth: .infinity, alignment: isBot ? .leading : .trailing)

            if isBot {
                Spacer(minLength: Spacing.lg)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
