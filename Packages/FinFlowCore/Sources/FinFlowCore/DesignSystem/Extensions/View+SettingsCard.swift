import SwiftUI

// MARK: - Settings Card Style Modifier

private struct SettingsCardModifier: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(AppTypography.headline)

            content
        }
        .padding()
        .background(AppColors.settingsCardBackground)
        .cornerRadius(12)
    }
}

extension View {
    /// Applies consistent settings card styling with a title
    /// - Parameter title: The section title
    /// - Returns: A styled settings card view
    public func settingsCardStyle(title: String) -> some View {
        modifier(SettingsCardModifier(title: title))
    }
}
