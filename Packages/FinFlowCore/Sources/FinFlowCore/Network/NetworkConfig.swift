//
//  NetworkConfig.swift
//  FinFlowCore
//
//  Created by Nguyễn Văn Bảo on 26/12/25.
//

import Foundation

public protocol NetworkConfigProtocol: Sendable {
    var baseURL: String { get }
}

public struct NetworkConfig: NetworkConfigProtocol {
    public let baseURL: String

    public init(baseURL: String) {
        self.baseURL = baseURL
    }
}
