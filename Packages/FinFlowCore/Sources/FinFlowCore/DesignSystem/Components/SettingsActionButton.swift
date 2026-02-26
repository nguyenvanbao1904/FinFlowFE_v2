import SwiftUI

/// A reusable button for settings actions with consistent styling
public struct SettingsActionButton: View {
    let title: String
    let icon: String
    let role: ButtonRole?
    let action: () -> Void
    
    public init(
        title: String,
        icon: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.role = role
        self.action = action
    }
    
    public var body: some View {
        Button(role: role, action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .tint(role == .destructive ? .red : .primary)
    }
}
