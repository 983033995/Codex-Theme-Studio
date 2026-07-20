import Foundation
import XCTest
@testable import CodexThemeStudioApp

final class CodexThemeStudioAppTests: XCTestCase {
  func testRegistryV1Decodes() throws {
    let data = Data(#"{"schemaVersion":1,"generatedAt":"2026-07-20T00:00:00Z","themes":[{"id":"fortune-coder","name":"财神打工","version":"1.0.0","summary":"红金主题","author":"Community","sharedBy":"983033995","license":"CC-BY-4.0","createdAt":"2026-07-20T00:00:00Z","publishedAt":"2026-07-20T00:00:00Z","releaseTag":"theme-fortune-coder-v1.0.0","stats":{"downloads":88,"favorites":9},"minEngineVersion":"1.3.0","previewURL":null,"themeConfigURL":"https://example.com/theme.json","imageURL":"https://example.com/background.jpg","themeSHA256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","imageSHA256":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","themeBytes":810,"imageBytes":1024}],"pets":[]}"#.utf8)
    let registry = try JSONDecoder().decode(RegistryDocument.self, from: data)
    XCTAssertEqual(registry.schemaVersion, 1)
    XCTAssertEqual(registry.themes.first?.sharedBy, "983033995")
    XCTAssertEqual(registry.themes.first?.stats?.downloads, 88)
    XCTAssertEqual(registry.themes.first?.stats?.favorites, 9)
    XCTAssertTrue(registry.pets.isEmpty)
  }

  func testSHA256MatchesKnownValue() {
    XCTAssertEqual(
      PackageInstaller.sha256(Data("dream-skin".utf8)),
      "45a52c5cdbe2817c8a878cf7622329599dd0e82e3c2c7947cd822692b2c8fbf6"
    )
  }

  func testThemeSearchIncludesNameDetailAndID() {
    let theme = ThemeItem(
      id: "preset-fortune-coder",
      name: "财神打工",
      detail: "官方主题",
      origin: .bundled,
      imageURL: nil,
      directoryURL: URL(fileURLWithPath: "/tmp/theme"),
      remote: nil
    )
    XCTAssertTrue(theme.matches("财神"))
    XCTAssertTrue(theme.matches("官方"))
    XCTAssertTrue(theme.matches("fortune"))
    XCTAssertFalse(theme.matches("樱花"))
  }

  func testStartupPolicyRepairsOnlyOnceWhenCodexNeedsIt() {
    let needsRepair = EngineStatus(
      session: "stale",
      port: 9341,
      injectorAlive: false,
      cdpOk: false,
      codexRunning: true,
      themeName: "财神打工"
    )
    XCTAssertTrue(StartupPolicy.shouldAutoRepair(
      status: needsRepair,
      attempted: false,
      busy: false
    ))
    XCTAssertFalse(StartupPolicy.shouldAutoRepair(
      status: needsRepair,
      attempted: true,
      busy: false
    ))
    XCTAssertFalse(StartupPolicy.shouldAutoRepair(
      status: needsRepair,
      attempted: false,
      busy: true
    ))
  }

  func testStartupPolicyDoesNotRepairHealthyEngine() {
    let healthy = EngineStatus(
      session: "active",
      port: 9341,
      injectorAlive: true,
      cdpOk: true,
      codexRunning: true,
      themeName: "财神打工"
    )
    XCTAssertFalse(StartupPolicy.shouldAutoRepair(
      status: healthy,
      attempted: false,
      busy: false
    ))
  }

  func testStartupPolicyKeepsNewestManagerInstance() {
    let older = RunningManagerInstance(
      processIdentifier: 100,
      launchDate: Date(timeIntervalSince1970: 100)
    )
    let newer = RunningManagerInstance(
      processIdentifier: 101,
      launchDate: Date(timeIntervalSince1970: 200)
    )

    XCTAssertEqual(StartupPolicy.preferredManager(from: [newer, older]), newer)
  }

  func testStartupPolicyUsesPIDAsDeterministicTieBreaker() {
    let launchDate = Date(timeIntervalSince1970: 100)
    let lowerPID = RunningManagerInstance(processIdentifier: 100, launchDate: launchDate)
    let higherPID = RunningManagerInstance(processIdentifier: 101, launchDate: launchDate)

    XCTAssertEqual(
      StartupPolicy.preferredManager(from: [higherPID, lowerPID]),
      higherPID
    )
  }
}
