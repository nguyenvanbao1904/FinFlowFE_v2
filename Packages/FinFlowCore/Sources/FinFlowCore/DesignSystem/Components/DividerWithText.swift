//
//  DividerWithText.swift
//  FinFlowCore
//
//  Horizontal divider with centered text
//

import SwiftUI

/// Horizontal divider with centered text
public struct DividerWithText: View {
    public let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        HStack {
            Divider()

            Text(text)
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)

            Divider()
        }
    }
}
