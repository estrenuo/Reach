import Foundation
import Testing
@testable import ReachKit

@Suite struct WorkflowLogTests {
    @Test func stderrEndsUpInTheLog() {
        var log = WorkflowLog()
        log.record(workflow: "Hello World", object: "Script Filter", input: "hello Ada", output: "{\"items\":[]}",
                   errors: "warning: no name\n", status: 0, failure: nil)
        #expect(log.entries.map(\.kind) == [.ran, .output, .error])
        #expect(log.entries.last?.text == "warning: no name")
        #expect(log.shown(.errors).map(\.text) == ["warning: no name"])
        #expect(log.entries.first?.text == "Script Filter ran with “hello Ada”")
    }

    @Test func aFailedRunLogsWhy() {
        var log = WorkflowLog()
        log.record(workflow: "W", object: "Run Script", input: nil, output: "", errors: "", status: 2, failure: nil)
        #expect(log.shown(.errors).map(\.text) == ["Run Script ended with exit code 2."])
        log.record(workflow: "W", object: "Run Script", input: nil, output: "", errors: "", status: 0, failure: "Stopped.")
        #expect(log.shown(.errors).last?.text == "Stopped.")
    }

    @Test func copyAndClear() {
        var log = WorkflowLog()
        let date = Date(timeIntervalSince1970: 0)
        log.record(workflow: "W", object: "Run Script", input: "x", output: "", errors: "", status: 0, failure: nil, at: date)
        #expect(log.text(.all).hasSuffix("] [W] Run Script ran with “x”"))
        #expect(log.text(.errors).isEmpty)
        log.clear()
        #expect(log.entries.isEmpty)
    }

    @Test func keepsTheLastLines() {
        var log = WorkflowLog()
        for index in 0..<(WorkflowLog.limit + 10) {
            log.record(workflow: "W", object: "Run Script", input: "\(index)", output: "", errors: "", status: 0, failure: nil)
        }
        #expect(log.entries.count == WorkflowLog.limit)
        #expect(log.entries.last?.text == "Run Script ran with “\(WorkflowLog.limit + 9)”")
        #expect(Set(log.entries.map(\.id)).count == WorkflowLog.limit)
    }
}
