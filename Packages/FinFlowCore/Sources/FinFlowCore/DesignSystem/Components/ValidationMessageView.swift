import SwiftUI

/// A reusable view for displaying validation messages below form fields
public struct ValidationMessageView: View {
    public enum MessageType {
        case error
        case warning
        case success
        
        var color: Color {
            switch self {
            case .error: return .red
            case .warning: return .orange
            case .success: return .green
            }
        }
        
        var icon: String? {
            switch self {
            case .error: return "exclamationmark.circle"
            case .warning: return "exclamationmark.triangle"
            case .success: return "checkmark.circle"
            }
        }
    }
    
    let message: String
    let type: MessageType
    let showIcon: Bool
    
    public init(
        message: String,
        type: MessageType = .error,
        showIcon: Bool = false
    ) {
        self.message = message
        self.type = type
        self.showIcon = showIcon
    }
    
    public var body: some View {
        // swiftlint:disable:next no_hardcoded_spacing
        HStack(spacing: 4) {
            if showIcon, let icon = type.icon {
                Image(systemName: icon)
                    .font(AppTypography.labelSmall)
            }
            
            Text(message)
                .font(AppTypography.caption)
            
            Spacer()
        }
        .foregroundColor(type.color)
        // swiftlint:disable:next no_hardcoded_padding
        .padding(.horizontal, 4)
    }
}
