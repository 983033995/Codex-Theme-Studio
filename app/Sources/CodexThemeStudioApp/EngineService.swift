import AppKit
import Foundation

struct EngineService {
  private let fileManager = FileManager.default

  var engineRoot: URL? {
    let environment = ProcessInfo.processInfo.environment
    var candidates: [URL] = []
    if let explicit = environment["CODEX_THEME_STUDIO_ENGINE"], !explicit.isEmpty {
      candidates.append(URL(fileURLWithPath: explicit, isDirectory: true))
    }
    if let legacy = environment["CODEX_DREAM_SKIN_ENGINE"], !legacy.isEmpty {
      candidates.append(URL(fileURLWithPath: legacy, isDirectory: true))
    }
    candidates.append(
      fileManager.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex/codex-dream-skin-studio", isDirectory: true)
    )
    if let resourceURL = Bundle.main.resourceURL {
      candidates.append(resourceURL.appendingPathComponent("provider-engine", isDirectory: true))
    }
    candidates.append(
      URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        .deletingLastPathComponent()
    )

    return candidates.first { candidate in
      fileManager.isExecutableFile(
        atPath: candidate.appendingPathComponent("scripts/status-dream-skin-macos.sh").path
      )
    }
  }

  func status(deep: Bool = true) async throws -> EngineStatus {
    let script = try scriptURL("status-dream-skin-macos.sh")
    var arguments = ["--json"]
    if deep { arguments.append("--deep") }
    let result = try await ProcessRunner.run(executable: script, arguments: arguments)
    guard result.exitCode == 0 else {
      throw ThemeStudioError.commandFailed(commandMessage(result))
    }
    guard let data = result.standardOutput.data(using: .utf8) else {
      throw ThemeStudioError.invalidResponse
    }
    do {
      return try JSONDecoder().decode(EngineStatus.self, from: data)
    } catch {
      throw ThemeStudioError.invalidResponse
    }
  }

  func switchTheme(id: String) async throws {
    let script = try scriptURL("switch-theme-macos.sh")
    let result = try await ProcessRunner.run(
      executable: script,
      arguments: ["--id", id]
    )
    guard result.exitCode == 0 else {
      throw ThemeStudioError.commandFailed(commandMessage(result))
    }
  }

  func repair(restartExisting: Bool) async throws {
    let script = try scriptURL("start-dream-skin-macos.sh")
    var arguments: [String] = []
    if restartExisting { arguments.append("--restart-existing") }
    let result = try await ProcessRunner.run(executable: script, arguments: arguments)
    guard result.exitCode == 0 else {
      throw ThemeStudioError.commandFailed(commandMessage(result))
    }
  }

  func pause() async throws {
    let script = try scriptURL("pause-dream-skin-macos.sh")
    let result = try await ProcessRunner.run(executable: script, arguments: [])
    guard result.exitCode == 0 else {
      throw ThemeStudioError.commandFailed(commandMessage(result))
    }
  }

  func openCodex() {
    let candidates = [
      URL(fileURLWithPath: "/Applications/ChatGPT.app"),
      URL(fileURLWithPath: "/Applications/Codex.app"),
      fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications/ChatGPT.app"),
      fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Codex.app")
    ]
    if let app = candidates.first(where: { fileManager.fileExists(atPath: $0.path) }) {
      NSWorkspace.shared.openApplication(at: app, configuration: .init())
    }
  }

  private func scriptURL(_ name: String) throws -> URL {
    guard let root = engineRoot else { throw ThemeStudioError.engineMissing }
    let script = root.appendingPathComponent("scripts/\(name)")
    guard fileManager.isExecutableFile(atPath: script.path) else {
      throw ThemeStudioError.engineMissing
    }
    return script
  }

  private func commandMessage(_ result: ProcessResult) -> String {
    let error = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
    let output = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    if !error.isEmpty { return error }
    if !output.isEmpty { return output }
    return "操作失败（退出码 \(result.exitCode)）。"
  }
}
