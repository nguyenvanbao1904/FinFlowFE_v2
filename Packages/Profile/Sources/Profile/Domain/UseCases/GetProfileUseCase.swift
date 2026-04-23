//
//  GetProfileUseCase.swift
//  Profile
//
//  Use Case for retrieving the authenticated user's profile.
//

import FinFlowCore

public protocol GetProfileUseCaseProtocol: Sendable {
    func execute() async throws -> UserProfile
}

public struct GetProfileUseCase: GetProfileUseCaseProtocol {
    private let repository: ProfileRepositoryProtocol

    public init(repository: ProfileRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> UserProfile {
        return try await repository.getMyProfile()
    }
}
