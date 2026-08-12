import Testing

@testable import CodexMonitorCore

@Suite("Termination transaction")
struct TerminationTransactionTests {
  @Test("A second quit request cannot bypass an active shutdown")
  func rejectsDuplicateBegin() {
    var transaction = TerminationTransaction()

    let firstBegin = transaction.begin()
    let secondBegin = transaction.begin()
    #expect(firstBegin)
    #expect(!secondBegin)
    #expect(transaction.state == .stopping)
  }

  @Test("A failed or cancelled shutdown can be retried")
  func canRetryAfterFinish() {
    var transaction = TerminationTransaction()

    let firstBegin = transaction.begin()
    #expect(firstBegin)
    transaction.finish()
    #expect(transaction.state == .idle)
    let retryBegin = transaction.begin()
    #expect(retryBegin)
  }
}
