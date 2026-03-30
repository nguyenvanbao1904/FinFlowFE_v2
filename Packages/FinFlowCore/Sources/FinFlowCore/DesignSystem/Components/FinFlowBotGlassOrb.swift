//
//  FinFlowBotGlassOrb.swift
//  FinFlowCore
//
//  Quả cầu kính tối giản — chỉ icon Bot, góc dưới-phải; chấm đỏ khi có gợi ý mới.
//

import SwiftUI

/// Nút trợ lý dạng quả cầu kính (glassmorphism), không kèm bong bóng chữ.
public struct FinFlowBotGlassOrb: View {
    private let mascotAssetName: String?
    private let mascotBundle: Bundle
    private let showsNotificationDot: Bool
    private let onTap: () -> Void

    /// Đường kính ~46pt (trong khoảng 44–50).
    private static let diameter: CGFloat = Spacing.touchTarget + BorderWidth.medium * 2
    private static let innerInset: CGFloat = BorderWidth.medium

    private static let rimGradient = LinearGradient(
        colors: [
            Color.white.opacity(OpacityLevel.high),
            Color.white.opacity(OpacityLevel.ultraLight)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// - Parameters:
    ///   - mascotAssetName: ảnh robot trong Asset Catalog; `nil` = gradient + SF Symbol.
    ///   - mascotBundle: Bundle chứa asset.
    ///   - showsNotificationDot: Chấm đỏ khi có gợi ý chưa xem (sau này gắn API).
    ///   - onTap: Mở sheet / chat.
    public init(
        mascotAssetName: String? = nil,
        mascotBundle: Bundle = .main,
        showsNotificationDot: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.mascotAssetName = mascotAssetName
        self.mascotBundle = mascotBundle
        self.showsNotificationDot = showsNotificationDot
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(OpacityLevel.ultraLight),
                                Color.blue.opacity(OpacityLevel.ultraLight)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Circle()
                    .strokeBorder(Self.rimGradient, lineWidth: BorderWidth.hairline)

                orbContent
                    .frame(
                        width: Self.diameter - Self.innerInset * 2,
                        height: Self.diameter - Self.innerInset * 2
                    )
                    .clipShape(Circle())
            }
            .frame(width: Self.diameter, height: Self.diameter)
            .shadow(color: Color.black.opacity(OpacityLevel.ultraLight), radius: Spacing.xs, x: 0, y: BorderWidth.medium)
            .shadow(color: Color.blue.opacity(0.12), radius: Spacing.sm, x: 0, y: Spacing.xs)
            .overlay(alignment: .topTrailing) {
                if showsNotificationDot {
                    Circle()
                        .fill(AppColors.error)
                        .frame(width: BorderWidth.thick * 2, height: BorderWidth.thick * 2)
                        .overlay {
                            Circle()
                                .strokeBorder(Color.white.opacity(OpacityLevel.high), lineWidth: BorderWidth.hairline)
                        }
                        .offset(x: BorderWidth.medium, y: -BorderWidth.medium)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("FinFlow Bot, trợ lý gợi ý")
        .accessibilityHint(showsNotificationDot ? "Có gợi ý mới. Mở để xem chi tiết." : "Mở gợi ý trong ngày.")
    }

    @ViewBuilder
    private var orbContent: some View {
        if let name = mascotAssetName {
            Image(name, bundle: mascotBundle)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.35, green: 0.65, blue: 0.98),
                        Color(red: 0.12, green: 0.38, blue: 0.88)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(AppTypography.iconMedium.weight(.semibold))
                    .foregroundStyle(AppColors.textInverted)
            }
        }
    }
}
