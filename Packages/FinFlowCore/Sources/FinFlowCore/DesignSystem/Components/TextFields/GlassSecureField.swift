//
//  GlassSecureField.swift
//  FinFlowCore
//
//  Modern glassmorphism-styled secure field
//

import SwiftUI

/// Modern glassmorphism-styled secure field with icon
public struct GlassSecureField: View {
    public let icon: String
    public let placeholder: String
    @Binding public var text: String
    @State private var isSecured: Bool = true
    public var onFocusChange: ((Bool) -> Void)?

    // Track focus
    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String,
        icon: String,
        onFocusChange: ((Bool) -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.onFocusChange = onFocusChange
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 25)

            Group {
                if isSecured {
                    SecureField(placeholder, text: $text)
                        .textContentType(.password)
                        .focused($isFocused)
                        .onChange(of: isFocused) { _, newValue in
                            onFocusChange?(newValue)
                        }
                } else {
                    TextField(placeholder, text: $text)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($isFocused)
                        .onChange(of: isFocused) { _, newValue in
                            onFocusChange?(newValue)
                        }
                }
            }

            Button(action: { isSecured.toggle() }) {
                Image(systemName: isSecured ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
                    .contentTransition(.symbolEffect(.replace))
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
