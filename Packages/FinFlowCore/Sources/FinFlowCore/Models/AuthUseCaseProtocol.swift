import Foundation

// MARK: - Logout Use Case Protocol

/**
 Protocol: Logout Use Case
 
 Placed in FinFlowCore to allow feature modules (Dashboard, Identity) to use without circular dependency.
 
 Pattern: Shared protocol in base layer, implementation in feature module (Identity)
 */
public protocol LogoutUseCaseProtocol: Sendable {
    func execute() async throws
}
