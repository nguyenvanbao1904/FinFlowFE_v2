import FinFlowCore
import SwiftUI

public struct LockScreenView: View {
    @State private var viewModel: LockScreenViewModel
    @FocusState private var isFocused: Bool
    
    public init(viewModel: LockScreenViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    
    public var body: some View {
        ZStack {
            AppBackgroundGradient()
            
            VStack(spacing: Spacing.lg) {
                Spacer()
                
                // Avatar / User Info
                VStack(spacing: Spacing.sm) {
                    if let initial = viewModel.user.firstName?.first {
                        Text(String(initial).uppercased())
                            .font(AppTypography.largeTitle)
                            .foregroundColor(AppColors.backgroundLight[1])
                            .frame(width: 80, height: 80)
                            .background(Circle().fill(AppColors.primary))
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundStyle(AppColors.primary.opacity(0.6))
                    }
                    
                    Text("Xin chào, \(viewModel.user.firstName ?? "User")")
                        .font(AppTypography.headline)
                        .foregroundStyle(.primary)
                    
                    Text("Nhập mã PIN để tiếp tục")
                        .font(AppTypography.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // PIN Input (DesignSystem PINCodeInput; tap vùng ô để focus và nhập)
                PINCodeInput(
                    pin: $viewModel.pin,
                    isFocused: $isFocused,
                    displayMode: .dots
                )
                .disabled(viewModel.isLoading)
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.google)
                        .padding(.top, Spacing.xs)
                }
                
                Spacer()
                
                // Biometric Button
                if viewModel.canUseBiometrics {
                    Button {
                        Task {
                            await viewModel.requestBiometricUnlock()
                        }
                    } label: {
                        VStack(spacing: Spacing.xs) {
                            Image(systemName: "faceid")
                                .font(AppTypography.displayLarge)
                            Text("Mở khóa bằng Face ID")
                                .font(AppTypography.caption)
                        }
                        .foregroundStyle(AppColors.primary)
                    }
                    .padding(.bottom, Spacing.xl * 1.25)
                }
                
                // Logout / Switch Account
                Button("Đăng nhập tài khoản khác") {
                    Task {
                        await viewModel.signOut()
                    }
                }
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, Spacing.sm)
            }
            .padding(Spacing.md)
        }
        .task {
            // Auto trigger biometric on appear
            if viewModel.canUseBiometrics && viewModel.pin.isEmpty {
                await viewModel.requestBiometricUnlock()
            }
        }
        .onAppear {
            isFocused = true
        }
        .onChange(of: viewModel.pin) { _, newPin in
            Task {
                await viewModel.handlePINEntry(newPin)
            }
        }
    }
}
