//
//  Typography.swift
//  FinFlowCore
//
//  Centralized typography styles
//

import SwiftUI

/// Centralized typography styles
/// Updated to support Dynamic Type (Accessibility)
public enum AppTypography {
    // Sử dụng relativeTo để font 42pt này vẫn có thể scale nếu người dùng chọn chữ cực lớn
    public static let largeTitle = Font.system(size: 42, weight: .bold, design: .rounded)

    public static let title = Font.system(size: 28, weight: .bold, design: .rounded)

    // Các font dưới đây tự động scale theo hệ thống
    public static let headline = Font.headline
    public static let subheadline = Font.subheadline
    public static let body = Font.body
    public static let caption = Font.caption
    public static let buttonTitle = Font.subheadline.weight(.medium)
}
