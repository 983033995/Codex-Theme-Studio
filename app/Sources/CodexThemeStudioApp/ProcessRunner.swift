import Foundation

struct ProcessResult {
  let exitCode: Int32
  let standardOutput: String
  let standardError: String
}

enum ProcessRunner {
  static func run(
    executable: URL,
    arguments: [String],
    environment: [String: String] = [:]
  ) async throws -> ProcessResult {
    try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        let process = Process()
        let output = Pipe()
        let error = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = error
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

        do {
          try process.run()
          process.waitUntilExit()
          let outputData = output.fileHandleForReading.readDataToEndOfFile()
          let errorData = error.fileHandleForReading.readDataToEndOfFile()
          continuation.resume(returning: ProcessResult(
            exitCode: process.terminationStatus,
            standardOutput: String(decoding: outputData, as: UTF8.self),
            standardError: String(decoding: errorData, as: UTF8.self)
          ))
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }
}
