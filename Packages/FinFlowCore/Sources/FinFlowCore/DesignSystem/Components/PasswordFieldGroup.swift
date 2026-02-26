import SwiftUI

/// A component grouping password and password confirmation fields
/// Note: Validation logic is handled by ViewModel, this component only displays state
public struct PasswordFieldGroup<Field: Hashable>: View {
    @Binding var password: String
    @Binding var passwordConfirmation: String
    let passwordMessage: String?
    let passwordConfirmationMessage: String?
    let focusedField: FocusState<Field?>.Binding
    let passwordFieldIdentifier: Field
    let confirmationFieldIdentifier: Field
    let onPasswordFocusChange: (Bool) -> Void
    let onConfirmationFocusChange: (Bool) -> Void
    
    public let passwordPlaceholder: String
    public let confirmationPlaceholder: String

    public init(
        password: Binding<String>,
        passwordConfirmation: Binding<String>,
        passwordPlaceholder: String = "Mật khẩu",
        confirmationPlaceholder: String = "Xác nhận mật khẩu",
        passwordMessage: String? = nil,
        passwordConfirmationMessage: String? = nil,
        focusedField: FocusState<Field?>.Binding,
        passwordFieldIdentifier: Field,
        confirmationFieldIdentifier: Field,
        onPasswordFocusChange: @escaping (Bool) -> Void,
        onConfirmationFocusChange: @escaping (Bool) -> Void
    ) {
        self._password = password
        self._passwordConfirmation = passwordConfirmation
        self.passwordPlaceholder = passwordPlaceholder
        self.confirmationPlaceholder = confirmationPlaceholder
        self.passwordMessage = passwordMessage
        self.passwordConfirmationMessage = passwordConfirmationMessage
        self.focusedField = focusedField
        self.passwordFieldIdentifier = passwordFieldIdentifier
        self.confirmationFieldIdentifier = confirmationFieldIdentifier
        self.onPasswordFocusChange = onPasswordFocusChange
        self.onConfirmationFocusChange = onConfirmationFocusChange
    }
    
    public var body: some View {
        VStack(spacing: Spacing.xs) {
            // Password field
            GlassSecureField(
                text: $password,
                placeholder: passwordPlaceholder,
                icon: "lock"
            )
            .focused(focusedField, equals: passwordFieldIdentifier)
            .onChange(of: focusedField.wrappedValue == passwordFieldIdentifier) { _, isFocused in
                onPasswordFocusChange(isFocused)
            }
            .textContentType(.newPassword)
            
            if let message = passwordMessage {
                ValidationMessageView(message: message)
            }
            
            // Password confirmation field
            GlassSecureField(
                text: $passwordConfirmation,
                placeholder: confirmationPlaceholder,
                icon: "lock.fill"
            )
            .focused(focusedField, equals: confirmationFieldIdentifier)
            .onChange(of: focusedField.wrappedValue == confirmationFieldIdentifier) { _, isFocused in
                onConfirmationFocusChange(isFocused)
            }
            .textContentType(.newPassword)
            
            if let message = passwordConfirmationMessage {
                ValidationMessageView(message: message)
            }
        }
    }
}
