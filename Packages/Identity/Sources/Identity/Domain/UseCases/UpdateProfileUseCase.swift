import Foundation
import FinFlowCore

// MARK: - Update Profile Use Case

public protocol UpdateProfileUseCaseProtocol: Sendable {
    /// Cập nhật profile. Nhận dob là Date — UseCase tự format thành "yyyy-MM-dd".
    func execute(firstName: String, lastName: String, dob: Date) async throws -> UserProfile
}

public struct UpdateProfileUseCase: UpdateProfileUseCaseProtocol {
    private let repository: ProfileRepositoryProtocol

    public init(repository: ProfileRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(firstName: String, lastName: String, dob: Date) async throws -> UserProfile {
        let request = UpdateProfileRequest(
            firstName: firstName,
            lastName: lastName,
            dob: DOBFormatter.format(dob)
        )
        return try await repository.updateProfile(request: request)
    }
}
