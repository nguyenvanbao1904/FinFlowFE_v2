//
//  DashboardView.swift
//  Dashboard
//

import FinFlowCore
import SwiftUI
import Identity

public struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel

    public init(viewModel: DashboardViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
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
            .sheet(isPresented: $viewModel.shouldShowUpdateProfile, onDismiss: {
                Task {
                    await viewModel.refresh()
                }
            }) {
                UpdateProfileView(viewModel: viewModel.makeUpdateProfileViewModel())
                    .interactiveDismissDisabled()
            }
            .showCustomAlert(alert: $viewModel.alert)
        }
    }
}
