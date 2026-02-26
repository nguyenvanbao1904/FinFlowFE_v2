import LocalAuthentication
import Foundation

public final class BiometricAuthHandler: Sendable {
    
    public init() {}
    
    public func verifyBiometric(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        
        // Check if biometrics are available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        
        // Evaluate policy
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch {
            return false
        }
    }
    
    public func isBiometricAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
}
