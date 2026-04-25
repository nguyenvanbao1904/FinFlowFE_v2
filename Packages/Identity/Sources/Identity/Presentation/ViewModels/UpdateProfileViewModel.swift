import Foundation
import FinFlowCore
import Observation

@MainActor
@Observable
public final class UpdateProfileViewModel {
    public var firstName: String = ""
    public var lastName: String = ""
    public var dob: Date = Date()
    public var isLoading: Bool = false
    public var alert: AppErrorAlert?
    public var isSuccess: Bool = false

    private static let dobParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private let updateProfileUseCase: UpdateProfileUseCaseProtocol
    private let sessionManager: any SessionManagerProtocol
    private let onSuccess: () -> Void

    public init(
        updateProfileUseCase: UpdateProfileUseCaseProtocol,
        sessionManager: any SessionManagerProtocol,
        currentProfile: UserProfile? = nil,
        onSuccess: @escaping () -> Void = {}
    ) {
        self.updateProfileUseCase = updateProfileUseCase
        self.sessionManager = sessionManager
        self.onSuccess = onSuccess
        if let profile = currentProfile {
            self.firstName = profile.firstName ?? ""
            self.lastName = profile.lastName ?? ""
            // Parse dob string từ API ("yyyy-MM-dd") thành Date để hiển thị DatePicker
            if let dobString = profile.dob {
                if let date = Self.dobParser.date(from: dobString) {
                    self.dob = date
                }
            }
        }
    }

    public var isValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty
    }

    public func updateProfile() async {
        guard isValid else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let updatedProfile = try await updateProfileUseCase.execute(
                firstName: firstName,
                lastName: lastName,
                dob: dob
            )
            sessionManager.updateCurrentUser(updatedProfile)
            isSuccess = true
            Logger.info("Update profile success", category: "UpdateProfile")
            onSuccess()
        } catch {
            Logger.error("Update profile failed: \(error)", category: "UpdateProfile")
            alert = error.toHandledAlert(sessionManager: sessionManager, defaultTitle: "Lỗi cập nhật")
        }
    }
}
