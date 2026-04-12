//
//  FinFlowBotChatPlaceholderView.swift
//  FinFlowCore
//
//  Professional chat surface for FinFlow Bot.
//

import SwiftUI

private enum FinFlowBotChatDefaults {
    static let greeting =
        "Chào bạn, mình là FinFlow Bot. Hãy hỏi về chi tiêu, ngân sách hoặc danh mục đầu tư để mình phân tích nhanh cho bạn."
    static let resetGreeting =
        "Phiên chat mới đã sẵn sàng. Bạn muốn bắt đầu từ thu chi, ngân sách hay đầu tư?"
    static let fallbackError =
        "Mình đang gặp lỗi tạm thời khi truy cập dữ liệu. Bạn thử gửi lại giúp mình sau vài giây nhé."
}

/// Sheet chat FinFlow Bot theo phong cách native iOS.
public struct FinFlowBotChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var isBotTyping = false
    @State private var isLoadingHistory = false
    @State private var hasLoadedHistory = false
    @State private var showsResetDialog = false
    @State private var errorMessage: String?
    @State private var messages: [FinFlowBotChatMessage]
    @FocusState private var isComposerFocused: Bool

    private let quickPrompts: [String]
    private let initialPrompt: String?
    private let loadMessagesHandler: (@Sendable () async throws -> [FinFlowBotChatMessage])?
    private let sendMessageHandler: (@Sendable (String) async throws -> FinFlowBotSendResult)?
    private let resetConversationHandler: (@Sendable () async throws -> [FinFlowBotChatMessage])?

    public init(
        quickPrompts: [String] = [
            "Tóm tắt chi tiêu tuần này",
            "Kiểm tra ngân sách tháng này",
            "Gợi ý tối ưu danh mục đầu tư"
        ],
        initialPrompt: String? = nil,
        loadMessagesHandler: (@Sendable () async throws -> [FinFlowBotChatMessage])? = nil,
        sendMessageHandler: (@Sendable (String) async throws -> FinFlowBotSendResult)? = nil,
        resetConversationHandler: (@Sendable () async throws -> [FinFlowBotChatMessage])? = nil
    ) {
        self.quickPrompts = quickPrompts
        self.initialPrompt = initialPrompt
        self.loadMessagesHandler = loadMessagesHandler
        self.sendMessageHandler = sendMessageHandler
        self.resetConversationHandler = resetConversationHandler
        self._messages = State(initialValue: Self.defaultMessages())
    }

    public var body: some View {
        VStack(spacing: .zero) {
            List {
            Section {
                if shouldShowQuickPrompts {
                    botIntroCard
                        .listRowBackground(AppColors.settingsCardBackground)
                        .listRowSeparator(.hidden)
                        .listRowInsets(
                            EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md)
                        )

                    quickPromptSection
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(
                            EdgeInsets(top: .zero, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md)
                        )
                }

                if isLoadingHistory {
                    historyLoadingRow
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(
                            EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: .zero, trailing: Spacing.md)
                        )
                }

                ForEach(messages) { message in
                    FinFlowBotChatMessageRow(message: message)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(
                            EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: .zero, trailing: Spacing.md)
                        )
                }

                if isBotTyping {
                    botTypingRow
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(
                            EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: .zero, trailing: Spacing.md)
                        )
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.appBackground)
        .onTapGesture {
            isComposerFocused = false
        }

        composer
            .background(AppColors.appBackground)
        }
        .navigationTitle("FinFlow Bot")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Làm mới") {
                    showsResetDialog = true
                }
                .font(AppTypography.buttonTitle)
                .disabled(isBotTyping || isLoadingHistory)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Đóng") {
                    isComposerFocused = false
                    dismiss()
                }
                .font(AppTypography.buttonTitle)
            }
        }
        .task {
            if let prompt = initialPrompt {
                // Report mode: reset conversation for a clean slate, then auto-send.
                await resetConversationForReport()
                applyPrompt(prompt)
            } else {
                // Normal mode: load existing chat history.
                await loadConversationIfNeeded()
            }
        }
        .alert(
            "Không thể xử lý yêu cầu",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Đã có lỗi xảy ra.")
        }
        .confirmationDialog("Làm mới hội thoại?", isPresented: $showsResetDialog, titleVisibility: .visible) {
            Button("Làm mới", role: .destructive) {
                resetConversation()
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Các tin nhắn hiện tại sẽ được xoá khỏi phiên chat này.")
        }
    }

    private var botIntroCard: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(OpacityLevel.ultraLight))
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)

                Image(systemName: "sparkles")
                    .font(AppTypography.iconMedium)
                    .foregroundStyle(AppColors.accent)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: BorderWidth.hairline) {
                Text("Trợ lý tài chính cá nhân")
                    .font(AppTypography.headline)
                    .foregroundStyle(.primary)
                Text("Mình trả lời nhanh theo dữ liệu trong FinFlow và đưa gợi ý hành động cụ thể.")
                    .font(AppTypography.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var quickPromptSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(quickPrompts, id: \.self) { prompt in
                    Button(prompt) {
                        applyPrompt(prompt)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(AppTypography.caption)
                    .disabled(isLoadingHistory || isBotTyping)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Gợi ý câu hỏi nhanh")
    }

    private var historyLoadingRow: some View {
        HStack(spacing: Spacing.xs) {
            ProgressView()
                .controlSize(.small)
            Text("Đang tải lịch sử hội thoại...")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var botTypingRow: some View {
        HStack(spacing: Spacing.xs) {
            ProgressView()
                .controlSize(.small)
            Text("FinFlow Bot đang soạn...")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Tin nhắn")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            HStack(alignment: .bottom, spacing: Spacing.xs) {
                TextField("Hỏi về thu chi, ngân sách, đầu tư...", text: $draft, axis: .vertical)
                    .font(AppTypography.body)
                    .lineLimit(1...4)
                    .submitLabel(.send)
                    .onSubmit(sendMessage)
                    .focused($isComposerFocused)
                    .disabled(isLoadingHistory || isBotTyping)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(AppTypography.displaySmall)
                }
                .buttonStyle(.plain)
                .foregroundStyle(canSend ? AppColors.primary : AppColors.disabled)
                .disabled(!canSend)
                .accessibilityLabel("Gửi tin nhắn")
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(AppColors.cardBackground)
            .clipShape(.rect(cornerRadius: CornerRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(AppColors.inputBorderDefault, lineWidth: BorderWidth.hairline)
            )
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.xs)
        .background(AppColors.appBackground)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isBotTyping
            && !isLoadingHistory
    }

    private var shouldShowQuickPrompts: Bool {
        let hasUserMessage = messages.contains { $0.sender == .user }
        return !hasUserMessage
    }

    @MainActor
    private func applyPrompt(_ prompt: String) {
        draft = prompt
        isComposerFocused = false
        sendMessage()
    }

    @MainActor
    private func sendMessage() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isBotTyping else { return }

        isComposerFocused = false
        draft = ""
        messages.append(FinFlowBotChatMessage(sender: .user, text: trimmed, sentAt: Date()))
        isBotTyping = true

        Task { @MainActor in
            defer { isBotTyping = false }

            do {
                if let sendMessageHandler {
                    let result = try await sendMessageHandler(trimmed)
                    let assistantText = resolvedAssistantText(from: result)
                    messages.append(
                        FinFlowBotChatMessage(
                            sender: .bot,
                            text: assistantText,
                            sentAt: Date(),
                            citations: result.citations
                        )
                    )
                } else {
                    try await Task.sleep(nanoseconds: 650_000_000)
                    messages.append(
                        FinFlowBotChatMessage(
                            sender: .bot,
                            text: botReply(for: trimmed),
                            sentAt: Date()
                        )
                    )
                }
            } catch {
                errorMessage = error.localizedDescription
                messages.append(
                    FinFlowBotChatMessage(
                        sender: .bot,
                        text: FinFlowBotChatDefaults.fallbackError,
                        sentAt: Date()
                    )
                )
            }
        }
    }

    private func resolvedAssistantText(from result: FinFlowBotSendResult) -> String {
        let clarified = result.clarificationQuestion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let content = result.content.trimmingCharacters(in: .whitespacesAndNewlines)

        if result.needsClarification, !clarified.isEmpty {
            return clarified
        }
        if !content.isEmpty {
            return content
        }
        if !clarified.isEmpty {
            return clarified
        }
        return FinFlowBotChatDefaults.fallbackError
    }

    private func botReply(for prompt: String) -> String {
        let normalized = prompt.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        if normalized.contains("ngan sach") {
            return "Bạn có thể đặt ngưỡng cảnh báo ở mức 85% ngân sách để tránh vượt chi trước tuần cuối tháng."
        }
        if normalized.contains("chi tieu") || normalized.contains("thu chi") {
            return "Chi tiêu lớn nhất hiện nên gom theo 3 nhóm chính để thấy rõ khoản nào có thể cắt giảm ngay trong tuần này."
        }
        if normalized.contains("dau tu") || normalized.contains("co phieu") || normalized.contains("danh muc") {
            return "Mình gợi ý theo dõi tỷ trọng tiền mặt và biến động theo tuần để cân bằng rủi ro danh mục trước khi thêm vị thế mới."
        }
        return "Mình đã nhận câu hỏi. Bạn có thể hỏi cụ thể theo mốc thời gian như “7 ngày gần đây” hoặc “tháng này” để mình trả lời sát hơn."
    }

    @MainActor
    private func resetConversation() {
        Task { @MainActor in
            do {
                if let resetConversationHandler {
                    let reloaded = try await resetConversationHandler()
                    messages = reloaded.isEmpty ? Self.resetMessages() : reloaded
                } else {
                    messages = Self.resetMessages()
                }
            } catch {
                errorMessage = error.localizedDescription
                messages = Self.resetMessages()
            }
            draft = ""
            isBotTyping = false
            isComposerFocused = false
        }
    }

    /// Async version of reset — awaits the backend call so callers can
    /// sequence actions (e.g. reset → auto-send) within a `.task` block.
    @MainActor
    private func resetConversationForReport() async {
        do {
            if let resetConversationHandler {
                let reloaded = try await resetConversationHandler()
                messages = reloaded.isEmpty ? Self.resetMessages() : reloaded
            } else {
                messages = Self.resetMessages()
            }
        } catch {
            messages = Self.resetMessages()
        }
        draft = ""
        isBotTyping = false
        hasLoadedHistory = true
    }

    @MainActor
    private func loadConversationIfNeeded() async {
        guard !hasLoadedHistory else { return }
        hasLoadedHistory = true
        guard let loadMessagesHandler else { return }

        isLoadingHistory = true
        defer { isLoadingHistory = false }

        do {
            let history = try await loadMessagesHandler()
            if !history.isEmpty {
                messages = history
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func defaultMessages() -> [FinFlowBotChatMessage] {
        [
            FinFlowBotChatMessage(
                sender: .bot,
                text: FinFlowBotChatDefaults.greeting,
                sentAt: Date()
            )
        ]
    }

    private static func resetMessages() -> [FinFlowBotChatMessage] {
        [
            FinFlowBotChatMessage(
                sender: .bot,
                text: FinFlowBotChatDefaults.resetGreeting,
                sentAt: Date()
            )
        ]
    }
}

@available(*, deprecated, renamed: "FinFlowBotChatView")
public typealias FinFlowBotChatPlaceholderView = FinFlowBotChatView

private struct FinFlowBotChatMessageRow: View {
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

    var body: some View {
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
