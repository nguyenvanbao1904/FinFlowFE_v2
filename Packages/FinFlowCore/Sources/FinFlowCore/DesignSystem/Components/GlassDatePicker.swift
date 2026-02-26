//
//  GlassDatePicker.swift
//  FinFlowCore
//

import SwiftUI

/// Glassmorphism styled DatePicker
/// Consistent với các GlassTextField/GlassSecureField
public struct GlassDatePicker: View {
    @Binding public var date: Date
    public let label: String
    public let icon: String

    public init(
        date: Binding<Date>,
        label: String = "Ngày sinh",
        icon: String = "calendar"
    ) {
        self._date = date
        self.label = label
        self.icon = icon
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 25)

            DatePicker(label, selection: $date, displayedComponents: .date)
                .tint(AppColors.primary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, Spacing.sm)
        .background(.ultraThinMaterial)
        .cornerRadius(CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}
