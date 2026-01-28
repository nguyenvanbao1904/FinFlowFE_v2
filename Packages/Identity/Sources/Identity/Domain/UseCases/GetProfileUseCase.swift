//
//  GetProfileUseCase.swift
//  Identity
//
//  Use Case for retrieving the authenticated user's profile.
//

import FinFlowCore
import Foundation

public protocol GetProfileUseCaseProtocol: Sendable {
    func execute() async throws -> UserProfile
}

public struct GetProfileUseCase: GetProfileUseCaseProtocol {
    private let repository: AuthRepositoryProtocol

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> UserProfile {
        return try await repository.getMyProfile()
    }
}
