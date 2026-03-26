import FinFlowCore
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

struct ChartFullscreenSupport {
    static func preferredChartHeight(for containerSize: CGSize) -> CGFloat {
        let isLandscape = containerSize.width > containerSize.height
        let ratio: CGFloat = isLandscape ? 0.86 : 0.74
        let minHeight: CGFloat = isLandscape ? 320 : 420
        let maxHeight: CGFloat = isLandscape ? 420 : 760
        let proposed = containerSize.height * ratio
        return min(max(proposed, minHeight), maxHeight)
    }
}

struct ChartFullscreenContainer<Content: View>: View {
    let title: String
    let content: Content
    @Environment(\.dismiss) private var dismiss

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let isLandscape = proxy.size.width > proxy.size.height

                ZStack(alignment: .top) {
                    AppColors.appBackground.ignoresSafeArea()

                    if isLandscape {
                        ScrollView(.vertical, showsIndicators: true) {
                            content
                                .frame(maxWidth: .infinity, alignment: .top)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.top, Spacing.md)
                                .padding(.bottom, Spacing.xl)
                        }
                    } else {
                        content
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.top, Spacing.md)
                    }
                }
                .ignoresSafeArea(.keyboard)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Đóng") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
