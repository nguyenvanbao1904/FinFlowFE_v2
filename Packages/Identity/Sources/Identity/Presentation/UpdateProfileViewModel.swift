import Combine
import FinFlowCore
import Foundation

@MainActor
public class UpdateProfileViewModel: ObservableObject {
    @Published public var firstName: String = ""
    @Published public var lastName: String = ""
    @Published public var dob: Date = Date()
    @Published public var isLoading: Bool = false
    @Published public var error: AppError? = nil
    @Published public var isSuccess: Bool = false

    private let authRepository: AuthRepositoryProtocol

    public init(authRepository: AuthRepositoryProtocol, currentProfile: UserProfile? = nil) {
        self.authRepository = authRepository
        if let profile = currentProfile {
            self.firstName = profile.firstName ?? ""
            self.lastName = profile.lastName ?? ""
            if let dobString = profile.dob {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                if let date = formatter.date(from: dobString) {
                    self.dob = date
                }
            }
        }
    }

    public func updateProfile() async {
        guard !firstName.isEmpty, !lastName.isEmpty else {
            // Validation error
            return
        }

        isLoading = true
        defer { isLoading = false }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dobString = dateFormatter.string(from: dob)

        let request = UpdateProfileRequest(
            firstName: firstName,
            lastName: lastName,
            dob: dobString
        )

        do {
            _ = try await authRepository.updateProfile(request: request)
            isSuccess = true
            Logger.info("Update profile success", category: "UpdateProfile")
        } catch {
            Logger.error("Update profile failed: \(error)", category: "UpdateProfile")
            if let appError = error as? AppError {
                self.error = appError
            } else {
                self.error = .unknown
            }
        }
    }
}
