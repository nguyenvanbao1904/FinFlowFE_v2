import FinFlowCore
import SwiftUI

public struct UpdateProfileView: View {
    @State private var viewModel: UpdateProfileViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: UpdateProfileViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        @Bindable var vm = viewModel
        
        return NavigationView {
            Form {
                Section(header: Text("Thông tin cá nhân")) {
                    TextField("Họ", text: $vm.lastName)
                    TextField("Tên", text: $vm.firstName)
                    DatePicker(
                        "Ngày sinh",
                        selection: $vm.dob,
                        displayedComponents: .date
                    )
                }

                if let error = viewModel.error {
                    Section {
                        Text(error.localizedDescription)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button(action: {
                        Task {
                            await viewModel.updateProfile()
                        }
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Cập nhật")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(viewModel.firstName.isEmpty || viewModel.lastName.isEmpty || viewModel.isLoading)
                }
            }
            .navigationTitle("Cập nhật hồ sơ")
            .onChange(of: viewModel.isSuccess) { _, success in
                if success {
                    dismiss()
                }
            }
        }
    }
}
