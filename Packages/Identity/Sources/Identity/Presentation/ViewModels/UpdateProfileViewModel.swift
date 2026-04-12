import FinFlowCore
import Foundation
import Observation

@MainActor
@Observable
public class UpdateProfileViewModel {
    public var firstName: String = ""
    public var lastName: String = ""
    public var dob: Date = Date()
    public var isLoading: Bool = false
    public var error: AppError?
    public var isSuccess: Bool = false

    private let authRepository: AuthRepositoryProtocol
    private let sessionManager: any SessionManagerProtocol
    private let onSuccess: () -> Void

    public init(
        authRepository: AuthRepositoryProtocol,
        sessionManager: any SessionManagerProtocol,
        currentProfile: UserProfile? = nil,
        onSuccess: @escaping () -> Void = {}
    ) {
        self.authRepository = authRepository
        self.sessionManager = sessionManager
        self.onSuccess = onSuccess
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

    public var isValid: Bool {
        return !firstName.isEmpty && !lastName.isEmpty
    }

    public func updateProfile() async {
        guard isValid else { return }

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
            let updatedProfile = try await authRepository.updateProfile(request: request)
            
            // Sync with SessionManager
            sessionManager.updateCurrentUser(updatedProfile)
            
            isSuccess = true
            Logger.info("Update profile success", category: "UpdateProfile")
            onSuccess()  // Trigger dismiss callback
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
