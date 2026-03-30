import FinFlowCore
import SwiftUI  // BẮT BUỘC - Để dùng View, State, Environment...

public struct RegisterView: View {
    @State private var viewModel: RegisterViewModel
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var focusedField: RegisterField?

    public init(viewModel: RegisterViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        // Main view logic
        ZStack {
            AppColors.appBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    headerSection
                        .padding(.top, Spacing.lg)

                    RegisterFormSection(vm: viewModel, focusedField: $focusedField)
                        .padding(.horizontal)

                    registerButton
                        .padding(.horizontal)

                    footerSection
                        .padding(.bottom, Spacing.lg)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .alertHandler($viewModel.alert)
    }

    // MARK: - Subcomponents

    private var headerSection: some View {
        AppLogoHeader(
            title: "Tạo tài khoản mới",
            subtitle: "Bắt đầu quản lý tài chính thông minh"
        )
    }

    private var registerButton: some View {
        Button("Đăng ký") {
            Task { await viewModel.register() }
        }
        .primaryButton(isLoading: viewModel.isLoading)
        .disabled(!viewModel.isFormValid)
    }

    private var footerSection: some View {
        HStack {
            Text("Đã có tài khoản?")
                .foregroundStyle(.secondary)
            Button("Đăng nhập") {
                viewModel.navigateToLogin()
            }
            .fontWeight(.bold)
            .foregroundStyle(AppColors.primary)
        }
        .font(AppTypography.body)
    }
}
