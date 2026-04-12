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
        .interactiveDismissDisabled(true)
        .pinInputSheet(
            isPresented: $vm.showCreatePINSheet,
            pin: Binding(
                get: { vm.isConfirmStep ? vm.confirmPIN : vm.pin },
                set: { if vm.isConfirmStep { vm.confirmPIN = $0 } else { vm.pin = $0 } }
            ),
            title: vm.isConfirmStep ? "Xác Nhận Mã PIN" : "Tạo Mã PIN",
            subtitle: vm.isConfirmStep ? "Nhập lại mã PIN để xác nhận" : "Nhập 6 số bạn muốn sử dụng làm mã PIN",
            showConfirmButton: true,
            isLoading: vm.isProcessing,
            onComplete: { _ in
                if !vm.isConfirmStep {
                    Logger.debug("CreatePIN: confirm step -> move to confirm input", category: "PIN")
                    guard vm.pin.count == 6 else {
                        vm.alert = .validation(message: "Vui lòng nhập đủ 6 số")
                        return
                    }
                    withAnimation {
                        vm.isConfirmStep = true
                    }
                } else {
                    Logger.debug("CreatePIN: confirm attempt (lengths: pin=\(vm.pin.count), confirm=\(vm.confirmPIN.count))", category: "PIN")
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
                }
            },
            onCancel: vm.isConfirmStep ? {
                withAnimation {
                    vm.isConfirmStep = false
                    vm.confirmPIN = ""
                }
            } : nil,
            alert: $vm.alert
        )
    }
}
