//
//  CreatePINView.swift
//  Dashboard
//

import FinFlowCore
import SwiftUI

public struct CreatePINView: View {
    @State private var viewModel: CreatePINViewModel

    public init(viewModel: CreatePINViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        @Bindable var vm = viewModel

        return ZStack {
            AppColors.appBackground
                .ignoresSafeArea()

            CreatePINWelcomeView(onNext: {
                vm.showCreatePINSheet = true
            })
        }
        .ignoresSafeArea()
        .pinInputSheet(
            isPresented: $vm.showCreatePINSheet,
            pin: $vm.pin,
            title: "Tạo Mã PIN",
            subtitle: "Nhập 6 số bạn muốn sử dụng làm mã PIN",
            showConfirmButton: true,
            onComplete: { _ in
                Logger.debug("CreatePIN: confirm step -> move to confirm sheet", category: "PIN")
                guard vm.pin.count == 6 else {
                    vm.alert = .validation(message: "Vui lòng nhập đủ 6 số")
                    return
                }
                vm.showCreatePINSheet = false
                vm.showConfirmPINSheet = true
            },
            // Hủy mặc định, không làm gì để tránh đóng sheet ngoài ý muốn
            alert: $vm.alert
        )
        .pinInputSheet(
            isPresented: $vm.showConfirmPINSheet,
            pin: $vm.confirmPIN,
            title: "Xác Nhận Mã PIN",
            subtitle: "Nhập lại mã PIN để xác nhận",
            showConfirmButton: true,
            isLoading: vm.isProcessing,
            onComplete: { _ in
                Logger.debug("CreatePIN: confirm attempt pin=\(vm.pin), confirm=\(vm.confirmPIN)", category: "PIN")
                // Validate locally to keep user on confirm step
                guard vm.confirmPIN.count == 6 else {
                    Logger.debug("CreatePIN: confirm length invalid", category: "PIN")
                    vm.alert = .validation(message: "Vui lòng nhập đủ 6 số")
                    return
                }
                guard vm.pin == vm.confirmPIN else {
                    Logger.debug("CreatePIN: confirm mismatch -> reset confirm only", category: "PIN")
                    vm.alert = .validation(message: "Mã PIN không khớp. Vui lòng thử lại.")
                    vm.confirmPIN = ""
                    return
                }
                Logger.debug("CreatePIN: confirm matched, calling createPIN()", category: "PIN")
                Task { await viewModel.createPIN() }
            },
            alert: $vm.alert
        )
    }
}
