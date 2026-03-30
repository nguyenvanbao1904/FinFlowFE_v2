//
//  FinFlowBotChatPlaceholderView.swift
//  FinFlowCore
//
//  Nội dung đầy đủ “Gợi ý trong ngày” — mở từ bottom sheet (sau thay bằng chat AI).
//

import SwiftUI

/// Sheet gợi ý / chat FinFlow Bot (placeholder).
/// Dùng `List` thay cho `ScrollView` để tránh lỗi layout trắng khi sheet có `.medium` + `NavigationStack`.
public struct FinFlowBotChatPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    private let insightBody: String

    public init(
        insightBody: String = """
        *bíp bíp* Chào bạn, mình là FinFlow Bot.

        Gợi ý trong ngày — sắp tới mình sẽ tóm tắt giúp bạn: tình hình thu chi, ngân sách còn lại, và cổ phiếu đáng chú ý trong danh mục, dựa trên dữ liệu thật trong FinFlow.

        Hiện mình vẫn đang “nạp dữ liệu” từ ví của bạn. Khi sẵn sàng, bạn chỉ cần chạm quả cầu kính ở góc màn hình để xem gợi ý mới nhất — gọn mà không làm phiền lúc bạn xem số dư.
        """
    ) {
        self.insightBody = insightBody
    }

    public var body: some View {
        List {
            Section {
                Text(insightBody)
                    .font(AppTypography.body)
                    .foregroundStyle(.primary)
                    .listRowBackground(AppColors.settingsCardBackground)
            } header: {
                Label("Gợi ý trong ngày", systemImage: "sparkles")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.accent)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.appBackground)
        .navigationTitle("FinFlow Bot")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Đóng") {
                    dismiss()
                }
                .font(AppTypography.buttonTitle)
            }
        }
    }
}
