//
//  GlassTextField.swift
//  FinFlowCore
//
//  Modern glassmorphism-styled text field
//

import SwiftUI
import UIKit

/// Modern glassmorphism-styled text field with icon & Focus state
public struct GlassTextField: View {
    public let icon: String
    public let placeholder: String
    @Binding public var text: String
    public var keyboardType: UIKeyboardType
    public var onFocusChange: ((Bool) -> Void)?

    // Track focus state để highlight viền
    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String,
        icon: String,
        keyboardType: UIKeyboardType = .default,
        onFocusChange: ((Bool) -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.keyboardType = keyboardType
        self.onFocusChange = onFocusChange
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 25)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.none)
                .keyboardType(keyboardType)
                .focused($isFocused)
                .onChange(of: isFocused) { _, newValue in
                    onFocusChange?(newValue)
                }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, Spacing.sm)
        .background(.ultraThinMaterial)
        .cornerRadius(CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(
                    isFocused ? AppColors.primary.opacity(0.6) : Color.white.opacity(0.1),
                    lineWidth: isFocused ? 1 : 0.5
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}
