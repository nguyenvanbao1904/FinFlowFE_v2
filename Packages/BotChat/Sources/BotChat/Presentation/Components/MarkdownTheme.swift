import FinFlowCore
import MarkdownUI
import SwiftUI

extension Theme {
    @MainActor
    static var finflowChat: Theme {
        Theme.gitHub
            .text {
                ForegroundColor(.primary)
                FontSize(.em(1.0))
            }
            .heading1 { config in
                config.label
                    .markdownMargin(top: 10, bottom: 4)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.25))
                    }
            }
            .heading2 { config in
                config.label
                    .markdownMargin(top: 8, bottom: 4)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.15))
                    }
            }
            .heading3 { config in
                config.label
                    .markdownMargin(top: 6, bottom: 2)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.05))
                    }
            }
            .paragraph { config in
                config.label
                    .markdownMargin(top: 2, bottom: 6)
            }
            .listItem { config in
                config.label
                    .markdownMargin(top: 2)
            }
            .table { config in
                config.label
                    .markdownMargin(top: 8, bottom: 8)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .tableCell { config in
                let isHeader = config.row == 0
                config.label
                    .markdownTextStyle {
                        FontSize(.em(0.9))
                        if isHeader { FontWeight(.semibold) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(.vertical, Spacing.xs)
                    .padding(.horizontal, CornerRadius.small)
                    .background(isHeader ? AnyShapeStyle(Color.primary.opacity(0.08)) : AnyShapeStyle(Color.clear))
            }
    }
}
