//
//  DashboardView.swift
//  Dashboard
//

import FinFlowCore
import Identity
import SwiftUI

public struct DashboardView: View {
    @State private var viewModel: DashboardViewModel

    public init(viewModel: DashboardViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        @Bindable var vm = viewModel

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let p = viewModel.profile {
                    Text("Chào mừng, \(p.firstName ?? "") \(p.lastName ?? "")!")
                        .font(.title)
                        .bold()

                    Text("Email: \(p.email)")
                        .font(.body)

                    Text("Vai trò: \(p.roles.joined(separator: ", "))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Đăng xuất") {
                        Task {
                            await viewModel.logout()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
        }
        .padding()
        .task {
            await viewModel.loadProfile()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .navigationTitle("Dashboard")
        .sheet(
            isPresented: $vm.shouldShowUpdateProfile,
            onDismiss: {
                Task {
                    await viewModel.refresh()
                }
            }
        ) {
            UpdateProfileView(viewModel: viewModel.makeUpdateProfileViewModel())
                .interactiveDismissDisabled()
        }
        .showCustomAlert(alert: $vm.alert)
    }
}
