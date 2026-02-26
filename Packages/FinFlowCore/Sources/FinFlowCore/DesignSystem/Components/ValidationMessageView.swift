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
        HStack(spacing: 4) {
            if showIcon, let icon = type.icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            
            Text(message)
                .font(.caption)
            
            Spacer()
        }
        .foregroundColor(type.color)
        .padding(.horizontal, 4)
    }
}
