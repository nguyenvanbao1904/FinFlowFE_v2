import SwiftUI

// MARK: - Settings Card Style Modifier

private struct SettingsCardModifier: ViewModifier {
    let title: String
    
    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
            
            content
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

public extension View {
    /// Applies consistent settings card styling with a title
    /// - Parameter title: The section title
    /// - Returns: A styled settings card view
    func settingsCardStyle(title: String) -> some View {
        modifier(SettingsCardModifier(title: title))
    }
}
