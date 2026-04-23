import Testing
import Foundation
@testable import Transaction
import FinFlowCore

// MARK: - AnalyzeTextUseCase Tests
// UseCase tạo AnalyzeTransactionRequest từ text input và forward xuống repository.

@Suite("AnalyzeTextUseCase")
struct AnalyzeTextUseCaseTests {

    private func makeSUT(
        repository: MockTransactionRepository = MockTransactionRepository()
    ) -> (sut: AnalyzeTextUseCase, repository: MockTransactionRepository) {
        let sut = AnalyzeTextUseCase(repository: repository)
        return (sut, repository)
    }

    // MARK: - Success Path

    @Test("execute thành công trả về AnalyzeTransactionResponse từ repository")
    func execute_success_returnsAnalysisFromRepository() async throws {
        let (sut, repository) = makeSUT()
        repository.stubbedAnalyzeResult = AnalyzeTransactionResponse.mock()

        let result = try await sut.execute(text: "Cà phê 50k")

        #expect(result.amount == 50_000)
        #expect(result.type == .expense)
    }

    @Test("execute tạo request đúng từ text và forward xuống repository")
    func execute_createsRequestFromTextAndForwardsToRepository() async throws {
        let trackingRepository = TrackingAnalyzeRepository()
        let sut = AnalyzeTextUseCase(repository: trackingRepository)

        _ = try await sut.execute(text: "Nhận lương tháng 4: 10 triệu")

        let captured = try #require(trackingRepository.lastAnalyzeRequest)
        #expect(captured.text == "Nhận lương tháng 4: 10 triệu")
    }

    @Test("execute gọi repository đúng 1 lần")
    func execute_callsRepositoryOnce() async throws {
        let trackingRepository = TrackingAnalyzeRepository()
        let sut = AnalyzeTextUseCase(repository: trackingRepository)

        _ = try await sut.execute(text: "Ăn trưa 80k")

        #expect(trackingRepository.analyzeCallCount == 1)
    }

    @Test("execute với text dài → forward toàn bộ text xuống repository")
    func execute_withLongText_forwardsFullTextToRepository() async throws {
        let trackingRepository = TrackingAnalyzeRepository()
        let sut = AnalyzeTextUseCase(repository: trackingRepository)
        let longText = "Hôm nay mua sắm tại siêu thị Big C, tổng tiền 350.000đ cho thực phẩm và đồ dùng gia đình"

        _ = try await sut.execute(text: longText)

        let captured = try #require(trackingRepository.lastAnalyzeRequest)
        #expect(captured.text == longText)
    }

    // MARK: - Response Variants

    @Test("execute khi AI phát hiện income → trả về type income")
    func execute_whenIncomeDetected_returnsIncomeType() async throws {
        let (sut, repository) = makeSUT()
        repository.stubbedAnalyzeResult = AnalyzeTransactionResponse(
            amount: 10_000_000, type: .income,
            suggestedCategoryId: nil, suggestedAccountId: nil,
            note: "Lương", transactionDate: nil
        )

        let result = try await sut.execute(text: "Nhận lương 10 triệu")

        #expect(result.type == .income)
    }

    @Test("execute khi AI không nhận ra amount → trả về nil amount")
    func execute_whenAmountNotDetected_returnsNilAmount() async throws {
        let (sut, repository) = makeSUT()
        repository.stubbedAnalyzeResult = AnalyzeTransactionResponse(
            amount: nil, type: .expense,
            suggestedCategoryId: nil, suggestedAccountId: nil,
            note: nil, transactionDate: nil
        )

        let result = try await sut.execute(text: "chi tiêu gì đó")

        #expect(result.amount == nil)
    }

    // MARK: - Error Propagation

    @Test("execute khi repository throw → propagate error")
    func execute_whenRepositoryThrows_propagatesError() async {
        let (sut, repository) = makeSUT()
        repository.errorToThrow = MockError.networkFailure

        await #expect(throws: MockError.networkFailure) {
            _ = try await sut.execute(text: "Cà phê 50k")
        }
    }

    @Test("execute khi lỗi → không retry tự động")
    func execute_onError_doesNotRetry() async {
        let trackingRepository = TrackingAnalyzeRepository()
        trackingRepository.errorToThrow = MockError.networkFailure
        let sut = AnalyzeTextUseCase(repository: trackingRepository)

        _ = try? await sut.execute(text: "test")

        #expect(trackingRepository.analyzeCallCount == 1)
    }
}

// MARK: - Tracking Mock

private final class TrackingAnalyzeRepository: MockTransactionRepository {
    var analyzeCallCount = 0
    var lastAnalyzeRequest: AnalyzeTransactionRequest?

    override func analyzeTransaction(request: AnalyzeTransactionRequest) async throws -> AnalyzeTransactionResponse {
        if let error = errorToThrow { throw error }
        analyzeCallCount += 1
        lastAnalyzeRequest = request
        return stubbedAnalyzeResult
    }
}
