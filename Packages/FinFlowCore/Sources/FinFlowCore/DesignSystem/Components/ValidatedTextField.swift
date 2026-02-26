import SwiftUI

/// A text field with integrated validation message display and focus handling
public struct ValidatedTextField<Field: Hashable>: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    let validationMessage: String?
    let focusedField: FocusState<Field?>.Binding
    let fieldIdentifier: Field
    let onFocusChange: (Bool) -> Void
    let textContentType: UITextContentType?
    
    public init(
        text: Binding<String>,
        placeholder: String,
        icon: String,
        validationMessage: String? = nil,
        focusedField: FocusState<Field?>.Binding,
        fieldIdentifier: Field,
        textContentType: UITextContentType? = nil,
        onFocusChange: @escaping (Bool) -> Void
    ) {
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.validationMessage = validationMessage
        self.focusedField = focusedField
        self.fieldIdentifier = fieldIdentifier
        self.textContentType = textContentType
        self.onFocusChange = onFocusChange
    }
    
    public var body: some View {
        VStack(spacing: Spacing.xs) {
            GlassTextField(
                text: $text,
                placeholder: placeholder,
                icon: icon
            )
            .focused(focusedField, equals: fieldIdentifier)
            .onChange(of: focusedField.wrappedValue == fieldIdentifier) { _, isFocused in
                onFocusChange(isFocused)
            }
            .textContentType(textContentType)
            
            if let message = validationMessage {
                ValidationMessageView(message: message)
            }
        }
    }
}
