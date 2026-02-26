import XCTest
@testable import FinFlowCore

final class SessionStateTests: XCTestCase {
    func testIsAuthenticatedTrueOnlyForAuthenticatedCase() {
        XCTAssertTrue(SessionState.authenticated(token: "t").isAuthenticated)
    }

    func testIsAuthenticatedFalseForNonAuthenticatedCases() {
        let states: [SessionState] = [
            .loading,
            .unauthenticated,
            .welcomeBack(email: "a@b.com", firstName: nil, lastName: nil),
            .refreshing,
            .sessionExpired(email: "a@b.com", firstName: nil, lastName: nil)
        ]

        states.forEach { XCTAssertFalse($0.isAuthenticated) }
    }
}
