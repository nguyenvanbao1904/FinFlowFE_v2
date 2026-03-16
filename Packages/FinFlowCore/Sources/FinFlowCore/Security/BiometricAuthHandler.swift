import Foundation
import LocalAuthentication

public protocol BiometricVerifying: Sendable {
    func verifyBiometric(reason: String) async -> Bool
    func isBiometricAvailable() -> Bool
}

public final class BiometricAuthHandler: BiometricVerifying, Sendable {

    public init() {}

    public func verifyBiometric(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?

        // Check if biometrics are available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        else {
            return false
        }

        // Evaluate policy
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
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
