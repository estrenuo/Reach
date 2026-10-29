import Foundation
import ReachKit

/// What a workflow script did: its output, its errors and how it ended.
struct ScriptResult: Sendable, Equatable {
    var output = Data()
    var errors = ""
    var status: Int32 = 0
    /// Set when the script could not start, or was stopped.
    var failure: String?

    var succeeded: Bool { failure == nil && status == 0 }
    var text: String { String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) }
}

/// Runs a workflow script off the main thread (S-041). Cancelling the task
/// stops the process, so a script for an old query never keeps running.
nonisolated enum ScriptRunner {
    static func run(_ command: ScriptCommand) async -> ScriptResult {
        let process = RunningScript()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    continuation.resume(returning: process.run(command))
                }
            }
        } onCancel: {
            process.stop()
        }
    }
}

/// One process, guarded so `stop()` can come from another thread at any time.
private nonisolated final class RunningScript: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var stopped = false

    func run(_ command: ScriptCommand) -> ScriptResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments
        process.currentDirectoryURL = command.directory
        process.environment = ProcessInfo.processInfo.environment.merging(command.environment) { _, new in new }
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        process.standardInput = FileHandle.nullDevice

        let started: String? = lock.withLock {
            guard !stopped else { return "Stopped." }
            self.process = process
            do {
                try process.run()
                return nil
            } catch {
                return "Unable to run \(command.executable): \(error.localizedDescription)"
            }
        }
        if let started { return ScriptResult(failure: started) }

        // Both pipes are read at once, so a script that writes a lot to one never blocks.
        let errorData = Collected()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            errorData.data = errors.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        group.wait()
        process.waitUntilExit()
        let wasStopped = lock.withLock { stopped }
        return ScriptResult(output: data, errors: String(decoding: errorData.data, as: UTF8.self),
                            status: process.terminationStatus, failure: wasStopped ? "Stopped." : nil)
    }

    func stop() {
        lock.withLock {
            stopped = true
            if process?.isRunning == true { process?.terminate() }
        }
    }
}

private nonisolated final class Collected: @unchecked Sendable {
    var data = Data()
}
