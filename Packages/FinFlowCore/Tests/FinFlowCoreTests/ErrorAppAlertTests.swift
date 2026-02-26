import XCTest
@testable import FinFlowCore

final class ErrorAppAlertTests: XCTestCase {
    func testUnauthorizedMapsToAuthAlert() {
        let alert = AppError.unauthorized("expired").toAppAlert()
        XCTAssertEqual(alert, .auth(message: "expired"))
    }

    func testUnknownErrorMapsToGeneralAlert() {
        struct DummyError: Error {}
        let alert = DummyError().toAppAlert(defaultTitle: "Oops")
        XCTAssertEqual(alert, .general(title: "Oops", message: "The operation couldn’t be completed. (DummyError error 0.)"))
    }
}
