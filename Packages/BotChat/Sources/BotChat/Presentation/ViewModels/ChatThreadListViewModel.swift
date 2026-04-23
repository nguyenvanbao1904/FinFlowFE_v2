import FinFlowCore
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
public final class ChatThreadListViewModel {
    public var threads: [ChatThreadResponse] = []
    public var isLoading = false
    public var errorMessage: String?

    private let gateway: BotChatGateway

    public init(gateway: BotChatGateway) {
        self.gateway = gateway
    }

    public func loadThreads() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let loaded = try await gateway.loadThreads()
            threads = loaded.sorted {
                ($0.updatedAt ?? $0.createdAt ?? "") > ($1.updatedAt ?? $1.createdAt ?? "")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func createThread() async -> String? {
        do {
            let thread = try await gateway.createThread(title: nil)
            threads.insert(thread, at: 0)
            return thread.id
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    public func deleteThread(at offsets: IndexSet) {
        let toDelete = offsets.compactMap { threads[safe: $0] }
        threads.remove(atOffsets: offsets)

        Task {
            for thread in toDelete {
                do {
                    try await gateway.deleteThread(threadId: thread.id)
                } catch {
                    errorMessage = error.localizedDescription
                    await loadThreads()
                    break
                }
            }
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
