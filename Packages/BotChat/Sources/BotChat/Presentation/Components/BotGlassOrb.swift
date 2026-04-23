import FinFlowCore
import SwiftUI

public struct FinFlowBotGlassOrb: View {
    private let mascotAssetName: String?
    private let mascotBundle: Bundle
    private let showsNotificationDot: Bool
    private let onTap: () -> Void

    private static let diameter: CGFloat = Spacing.touchTarget + BorderWidth.medium * 2
    private static let innerInset: CGFloat = BorderWidth.medium

    private static let rimGradient = LinearGradient(
        colors: [
            AppColors.glassRimHighlight,
            AppColors.glassRimSubtle
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

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
                                AppColors.glassRimSubtle,
                                AppColors.glassBlueTint
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
            .shadow(color: AppColors.glassShadowDark, radius: Spacing.xs, x: 0, y: BorderWidth.medium)
            .shadow(color: AppColors.glassShadowBlue, radius: Spacing.sm, x: 0, y: Spacing.xs)
            .overlay(alignment: .topTrailing) {
                if showsNotificationDot {
                    Circle()
                        .fill(AppColors.error)
                        .frame(width: BorderWidth.thick * 2, height: BorderWidth.thick * 2)
                        .overlay {
                            Circle()
                                .strokeBorder(AppColors.glassRimHighlight, lineWidth: BorderWidth.hairline)
                        }
                        .offset(x: BorderWidth.medium, y: -BorderWidth.medium)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
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
                        AppColors.botOrbGradientTop,
                        AppColors.botOrbGradientBottom
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
