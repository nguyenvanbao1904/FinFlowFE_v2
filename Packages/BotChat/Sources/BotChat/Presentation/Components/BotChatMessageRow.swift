import FinFlowCore
import MarkdownUI
import SwiftUI

public struct FinFlowBotChatMessageRow: View {
    let message: FinFlowBotChatMessage

    private var isBot: Bool { message.sender == .bot }

    private var citationSummary: String? {
        let normalized = message.citations
            .compactMap { citation -> String? in
                let title = citation.sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return nil }
                if let page = citation.pageNumber { return "\(title) · tr.\(page)" }
                return title
            }
        guard !normalized.isEmpty else { return nil }
        let head = normalized.prefix(2).joined(separator: " • ")
        let tailCount = max(0, normalized.count - 2)
        return "Nguồn: \(head)\(tailCount > 0 ? " +\(tailCount)" : "")"
    }

    public init(message: FinFlowBotChatMessage) {
        self.message = message
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: .zero) {
            if isBot {
                botContent
            } else {
                Spacer(minLength: Spacing.xl)
                userBubble
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Bot: no card, text directly on background

    private var botContent: some View {
        VStack(alignment: .leading, spacing: Spacing.xs / 2) {
            MarkdownWithTables(text: message.text)
            timeLabel
            if let citationSummary {
                Text(citationSummary)
                    .font(AppTypography.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.xs)
    }

    // MARK: - User: right-aligned bubble

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: Spacing.xs / 2) {
            Text(message.text)
                .font(AppTypography.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            timeLabel
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(AppColors.primary.opacity(OpacityLevel.light))
        .clipShape(.rect(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(AppColors.primary.opacity(OpacityLevel.medium), lineWidth: BorderWidth.hairline)
        )
    }

    private var timeLabel: some View {
        Text(message.sentAt.formatted(date: .omitted, time: .shortened))
            .font(AppTypography.caption2)
            .foregroundStyle(.tertiary)
    }
}

// MARK: - Markdown with horizontally scrollable tables

private struct MarkdownWithTables: View {
    let text: String

    var body: some View {
        // Split on table blocks so we can wrap each table in its own horizontal scroll.
        let parts = TableSplitter.split(text)
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                if part.isTable {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Markdown(part.content)
                            .markdownTheme(.finflowChat)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                } else if !part.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Markdown(part.content)
                        .markdownTheme(.finflowChat)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - Table splitter

private struct TextPart {
    let content: String
    let isTable: Bool
}

private enum TableSplitter {
    static func split(_ text: String) -> [TextPart] {
        var result: [TextPart] = []
        var nonTableLines: [String] = []
        var tableLines: [String] = []
        var inTable = false

        let lines = text.components(separatedBy: "\n")
        for line in lines {
            let isTableLine = line.hasPrefix("|") || isSeparatorLine(line)
            if isTableLine {
                if !inTable {
                    // flush non-table buffer
                    if !nonTableLines.isEmpty {
                        result.append(TextPart(content: nonTableLines.joined(separator: "\n"), isTable: false))
                        nonTableLines = []
                    }
                    inTable = true
                }
                tableLines.append(line)
            } else {
                if inTable {
                    // flush table buffer
                    result.append(TextPart(content: tableLines.joined(separator: "\n"), isTable: true))
                    tableLines = []
                    inTable = false
                }
                nonTableLines.append(line)
            }
        }
        // flush remaining
        if !tableLines.isEmpty {
            result.append(TextPart(content: tableLines.joined(separator: "\n"), isTable: true))
        }
        if !nonTableLines.isEmpty {
            result.append(TextPart(content: nonTableLines.joined(separator: "\n"), isTable: false))
        }
        return result
    }

    private static func isSeparatorLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return trimmed.allSatisfy { $0 == "-" || $0 == "|" || $0 == ":" || $0 == " " }
    }
}
