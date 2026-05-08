//
//  StableAddTransactionView.swift
//  FinFlowIos
//
//  Wrapper để giữ AddTransactionViewModel ổn định qua parent rebuilds.
//  Dùng @State(initialValue:) trick — SwiftUI chỉ init 1 lần, ignore subsequent calls.
//

import SwiftUI
import FinFlowCore
import Transaction

struct StableAddTransactionView: View {
    @State private var viewModel: AddTransactionViewModel
    private let autoTriggerMode: WidgetInputMode?

    init(viewModel: AddTransactionViewModel, autoTriggerMode: WidgetInputMode? = nil) {
        self._viewModel = State(initialValue: viewModel)
        self.autoTriggerMode = autoTriggerMode
    }

    var body: some View {
        AddTransactionView(viewModel: viewModel, autoTriggerMode: autoTriggerMode)
    }
}
