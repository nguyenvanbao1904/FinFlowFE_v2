//
//  PINInputSheet.swift
//  FinFlowCore
//
//  Reusable PIN input sheet modifier - Apple native popup style
//

import SwiftUI

public struct PINInputSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var pin: String

    let title: String
    let subtitle: String?
    let showConfirmButton: Bool
    let isLoading: Bool
    let displayMode: PINCodeInput.DisplayMode
    let allowDismissal: Bool
    let onComplete: (String) -> Void
    let onCancel: (() -> Void)?
    let onForgotPIN: (() -> Void)?
    let onDismiss: (() -> Void)?
    @Binding var alert: AppErrorAlert?

    public func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented, onDismiss: onDismiss) {
                PINInputSheetContent(
                    pin: $pin,
                    alert: $alert,
                    title: title,
                    subtitle: subtitle,
                    showConfirmButton: showConfirmButton,
                    isLoading: isLoading,
                    displayMode: displayMode,
                    onComplete: onComplete,
                    onCancel: onCancel,
                    onForgotPIN: onForgotPIN
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(!allowDismissal)
            }
    }
}

// Internal wrapper to manage focus state inside sheet
private struct PINInputSheetContent: View {
    @Binding var pin: String
    @FocusState private var isFocused: Bool
    @Binding var alert: AppErrorAlert?

    let title: String
    let subtitle: String?
    let showConfirmButton: Bool
    let isLoading: Bool
    let displayMode: PINCodeInput.DisplayMode
    let onComplete: (String) -> Void
    let onCancel: (() -> Void)?
    let onForgotPIN: (() -> Void)?

    var body: some View {
        PINInputView(
            pin: $pin,
            isFocused: $isFocused,
            title: title,
            subtitle: subtitle,
            showConfirmButton: showConfirmButton,
            isLoading: isLoading,
            displayMode: displayMode,
            onComplete: onComplete,
            onCancel: onCancel,
            onForgotPIN: onForgotPIN
        )
        .padding()
        .alertHandler($alert)
    }
}

// MARK: - View Extension
extension View {
    public func pinInputSheet(
        isPresented: Binding<Bool>,
        pin: Binding<String>,
        title: String = "Nhập mã PIN",
        subtitle: String? = nil,
        showConfirmButton: Bool = true,
        isLoading: Bool = false,
        displayMode: PINCodeInput.DisplayMode = .dots,
        allowDismissal: Bool = false,
        onComplete: @escaping (String) -> Void,
        onCancel: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        onForgotPIN: (() -> Void)? = nil,
        alert: Binding<AppErrorAlert?> = .constant(nil)
    ) -> some View {
        self.modifier(
            PINInputSheetModifier(
                isPresented: isPresented,
                pin: pin,
                title: title,
                subtitle: subtitle,
                showConfirmButton: showConfirmButton,
                isLoading: isLoading,
                displayMode: displayMode,
                allowDismissal: allowDismissal,
                onComplete: onComplete,
                onCancel: onCancel,
                onForgotPIN: onForgotPIN,
                onDismiss: onDismiss,
                alert: alert
            )
        )
    }
}
