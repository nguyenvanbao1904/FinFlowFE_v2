//
//  DailyInsightCard.swift
//  FinFlowCore
//
//  Khung gợi ý trong ngày — tin nhắn từ FinFlow Bot (robot thương hiệu + bong bóng thoại).
//

import SwiftUI

// MARK: - Bubble shape (đuôi trỏ về phía avatar)

private struct AIMessageBubbleShape: Shape {
    private let cornerRadius: CGFloat = CornerRadius.medium + BorderWidth.thin
    private let tailWidth: CGFloat = Spacing.xs
    private let tailHalfHeight: CGFloat = Spacing.xs - BorderWidth.medium

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let body = CGRect(
            x: tailWidth,
            y: 0,
            width: rect.width - tailWidth,
            height: rect.height
        )
        path.addRoundedRect(in: body, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        let midY = rect.midY
        path.move(to: CGPoint(x: tailWidth, y: midY - tailHalfHeight))
        path.addLine(to: CGPoint(x: 0, y: midY))
        path.addLine(to: CGPoint(x: tailWidth, y: midY + tailHalfHeight))
        path.closeSubpath()
        return path
    }
}

// MARK: - Card

/// Thẻ hiển thị đoạn văn ngắn dạng tin nhắn từ robot thương hiệu (FinFlow Bot).
public struct DailyInsightCard: View {
    private let senderName: String
    private let tagline: String
    private let message: String
    private let mascotAssetName: String?
    private let mascotBundle: Bundle

    private static let avatarDiameter: CGFloat = Spacing.touchTarget + Spacing.xs
    private static let avatarGlowDiameter: CGFloat = Spacing.touchTarget + Spacing.sm

    private static let bubbleOuterStroke = LinearGradient(
        colors: [
            Color.blue.opacity(0.42),
            Color.cyan.opacity(0.28),
            Color.purple.opacity(0.18)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private static let bubbleFill = LinearGradient(
        colors: [
            AppColors.cardBackground,
            Color.blue.opacity(0.05),
            Color.cyan.opacity(0.04)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private static let cardBackground = LinearGradient(
        stops: [
            .init(color: Color.blue.opacity(0.12), location: 0.0),
            .init(color: Color.cyan.opacity(0.07), location: 0.42),
            .init(color: Color.purple.opacity(0.06), location: 0.88),
            .init(color: AppColors.cardBackground.opacity(0.92), location: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private static let nameGradient = LinearGradient(
        colors: [
            Color(red: 0.12, green: 0.42, blue: 0.95),
            Color(red: 0.35, green: 0.55, blue: 0.98),
            Color(red: 0.45, green: 0.35, blue: 0.92)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// - Parameters:
    ///   - senderName: Tên hiển thị (mặc định FinFlow Bot).
    ///   - tagline: Dòng phụ (ví dụ “Tin nhắn trong ngày”).
    ///   - message: Nội dung chính.
    ///   - mascotAssetName: Tên ảnh trong Asset Catalog (ví dụ robot app icon). `nil` = icon hệ thống.
    ///   - mascotBundle: Bundle chứa asset (ứng dụng chính thường dùng `.main`).
    public init(
        senderName: String = "FinFlow Bot",
        tagline: String = "Tin nhắn trong ngày",
        message: String,
        mascotAssetName: String? = nil,
        mascotBundle: Bundle = .main
    ) {
        self.senderName = senderName
        self.tagline = tagline
        self.message = message
        self.mascotAssetName = mascotAssetName
        self.mascotBundle = mascotBundle
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            robotAvatar

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(senderName)
                        .font(AppTypography.headline)
                        .foregroundStyle(Self.nameGradient)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(tagline)
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                }

                ZStack(alignment: .topLeading) {
                    AIMessageBubbleShape()
                        .fill(Self.bubbleFill)
                        .overlay {
                            AIMessageBubbleShape()
                                .stroke(Self.bubbleOuterStroke, lineWidth: BorderWidth.thin)
                        }
                        .overlay {
                            AIMessageBubbleShape()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(OpacityLevel.high),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .center
                                    ),
                                    lineWidth: BorderWidth.hairline
                                )
                                .opacity(OpacityLevel.medium)
                        }
                        .shadow(color: Color.blue.opacity(0.14), radius: Spacing.xs, x: 0, y: Spacing.xs)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(message)
                            .font(AppTypography.body)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "sparkles")
                                .font(AppTypography.caption2)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Color.blue, Color.cyan.opacity(OpacityLevel.high))
                                .accessibilityHidden(true)
                            Text("Gợi ý dựa trên dữ liệu của bạn — sắp có thêm.")
                                .font(AppTypography.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.leading, Spacing.xs + Spacing.sm)
                    .padding(.trailing, Spacing.sm)
                    .padding(.vertical, Spacing.sm)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Spacing.lg)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(Self.cardBackground)
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(OpacityLevel.light),
                                Color.blue.opacity(0.14),
                                Color.cyan.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: BorderWidth.hairline
                    )
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(OpacityLevel.ultraLight),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .padding(Spacing.xs)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(senderName). \(tagline). \(message)")
    }

    @ViewBuilder
    private var robotAvatar: some View {
        let glowRadius = Self.avatarGlowDiameter / 2
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.cyan.opacity(0.38),
                            Color.blue.opacity(0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: Spacing.xs,
                        endRadius: glowRadius
                    )
                )
                .frame(width: Self.avatarGlowDiameter, height: Self.avatarGlowDiameter)

            if let name = mascotAssetName {
                Image(name, bundle: mascotBundle)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Self.avatarDiameter, height: Self.avatarDiameter)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(OpacityLevel.high),
                                        Color.white.opacity(OpacityLevel.light)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: BorderWidth.medium
                            )
                    }
                    .shadow(color: Color.black.opacity(0.12), radius: BorderWidth.medium, x: 0, y: Spacing.xs)
                    .shadow(color: Color.blue.opacity(0.35), radius: Spacing.sm, x: 0, y: Spacing.xs)
                    .accessibilityHidden(true)
            } else {
                fallbackSystemAvatar
            }
        }
    }

    private var fallbackSystemAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.35, green: 0.65, blue: 0.98),
                            Color(red: 0.12, green: 0.38, blue: 0.88)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: Self.avatarDiameter, height: Self.avatarDiameter)
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(OpacityLevel.low), lineWidth: BorderWidth.thin)
                }

            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(AppTypography.iconMedium.weight(.semibold))
                .foregroundStyle(AppColors.textInverted)
                .accessibilityHidden(true)
        }
        .shadow(color: Color.blue.opacity(0.28), radius: Spacing.xs, x: 0, y: Spacing.xs)
        .accessibilityHidden(true)
    }
}
