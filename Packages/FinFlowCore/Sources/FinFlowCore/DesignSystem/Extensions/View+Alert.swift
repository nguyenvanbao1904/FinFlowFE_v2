import SwiftUI

// MARK: - Alert Handler Extension
/// Centralized alert handling extension for SwiftUI Views
/// Provides consistent logging, haptics, and analytics for all alerts
extension View {
    
    /// Standard alert handler with automatic logging and haptic feedback
    /// - Parameters:
    ///   - alert: Binding to optional AppErrorAlert
    ///   - onDismiss: Optional callback when alert is dismissed
    /// - Returns: View with alert modifier applied
    public func alertHandler(
        _ alert: Binding<AppErrorAlert?>,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        self.alert(item: alert) { alertItem in
            // Centralized logic runs for EVERY alert
            handleAlertPresentation(alertItem)
            
            // Build and return the SwiftUI Alert
            return buildAlert(from: alertItem, onDismiss: onDismiss)
        }
    }
    
    // MARK: - Private Helpers
    
    /// Handles side effects when alert is presented
    private func handleAlertPresentation(_ alert: AppErrorAlert) {
        // 1. Logging
        logAlert(alert)
        
        // 2. Haptic Feedback
        triggerHapticFeedback(for: alert)
        
        // 3. Analytics (optional - can be enabled later)
        // trackAlertAnalytics(alert)
    }
    
    /// Logs alert information with type-appropriate emoji
    private func logAlert(_ alert: AppErrorAlert) {
        let emoji: String
        switch alert.alertType {
        case .error:
            emoji = "❌"
        case .success:
            emoji = "✅"
        case .warning:
            emoji = "⚠️"
        case .info:
            emoji = "ℹ️"
        }
        
        Logger.info("\(emoji) Alert: \(alert.title) - \(alert.message)", category: "UI")
    }
    
    /// Triggers appropriate haptic feedback based on alert type
    private func triggerHapticFeedback(for alert: AppErrorAlert) {
        let generator = UINotificationFeedbackGenerator()
        
        switch alert.alertType {
        case .error:
            generator.notificationOccurred(.error)
        case .success:
            generator.notificationOccurred(.success)
        case .warning, .info:
            generator.notificationOccurred(.warning)
        }
    }
    
    /// Builds SwiftUI Alert from AppErrorAlert
    private func buildAlert(
        from alert: AppErrorAlert,
        onDismiss: (() -> Void)?
    ) -> Alert {
        let titleText = Text(alert.title)
        let messageText = alert.subtitle.map { Text($0) }
        
        switch alert {
        case .network(let onRetry):
            return Alert(
                title: titleText,
                message: messageText,
                primaryButton: .default(Text("Thử lại"), action: onRetry),
                secondaryButton: .cancel { onDismiss?() }
            )
            
        case .authWithAction(_, let onOK):
            return Alert(
                title: titleText,
                message: messageText,
                dismissButton: .default(Text("OK")) {
                    onOK()
                    onDismiss?()
                }
            )
            
        case .success(_, let onOK):
            return Alert(
                title: titleText,
                message: messageText,
                dismissButton: .default(Text("OK")) {
                    onOK()
                    onDismiss?()
                }
            )
            
        default:
            return Alert(
                title: titleText,
                message: messageText,
                dismissButton: .default(Text("OK")) {
                    onDismiss?()
                }
            )
        }
    }
}
