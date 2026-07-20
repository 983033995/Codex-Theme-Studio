import Foundation

enum LibraryScope: String, CaseIterable, Identifiable {
  case themes = "主题"
  case pets = "宠物"
  case installed = "已安装"

  var id: String { rawValue }

  var systemImage: String {
    switch self {
    case .themes: return "paintpalette"
    case .pets: return "pawprint"
    case .installed: return "checkmark.circle"
    }
  }
}

enum PackageOrigin: String, Codable, Hashable {
  case bundled = "官方主题"
  case community = "社区主题"
  case local = "本地主题"
}

struct EngineStatus: Codable, Equatable {
  var session: String
  var port: Int
  var injectorAlive: Bool
  var cdpOk: Bool
  var codexRunning: Bool
  var themeName: String

  static let unavailable = EngineStatus(
    session: "off",
    port: 9341,
    injectorAlive: false,
    cdpOk: false,
    codexRunning: false,
    themeName: ""
  )

  var isHealthy: Bool {
    session == "active" && injectorAlive && cdpOk
  }

  var needsRepair: Bool {
    codexRunning && !cdpOk
  }

  var healthTitle: String {
    if isHealthy { return "守护正常 · 重启后自动恢复" }
    if needsRepair { return "Codex 需要重启一次以恢复主题" }
    if codexRunning { return "Codex 已打开 · 正在检测主题" }
    return "守护待命 · 打开 Codex 后自动检测"
  }
}

struct ThemeConfig: Codable, Hashable {
  let schemaVersion: Int
  let id: String
  let name: String
  let version: String?
  let description: String?
  let author: String?
  var sharedBy: String? = nil
  var createdAt: String? = nil
  let license: String?
  let minEngineVersion: String?
  let image: String
  var preview: String? = nil
  var tokens: String? = nil
  var decorations: String? = nil
  let tagline: String?
  let appearance: String?
}

struct PetConfig: Codable, Hashable {
  let schemaVersion: Int?
  let id: String
  let displayName: String
  let version: String?
  let author: String?
  var sharedBy: String? = nil
  var createdAt: String? = nil
  let license: String?
  let description: String?
  let spriteVersionNumber: Int
  let spritesheetPath: String
  var preview: String? = nil
}

struct RegistryStats: Codable, Hashable {
  let downloads: Int
  let favorites: Int
}

struct RegistryDocument: Codable {
  let schemaVersion: Int
  let generatedAt: String?
  let themes: [RegistryTheme]
  let pets: [RegistryPet]
}

struct RegistryTheme: Codable, Hashable, Identifiable {
  let id: String
  let name: String
  let version: String
  let summary: String?
  let author: String?
  var sharedBy: String? = nil
  let license: String?
  var createdAt: String? = nil
  var publishedAt: String? = nil
  var updatedAt: String? = nil
  var releaseTag: String? = nil
  var stats: RegistryStats? = nil
  var statsIssueURL: URL? = nil
  let minEngineVersion: String?
  let previewURL: URL?
  let themeConfigURL: URL
  let imageURL: URL
  let themeSHA256: String
  let imageSHA256: String
  let themeBytes: Int?
  let imageBytes: Int?
}

struct RegistryPet: Codable, Hashable, Identifiable {
  let id: String
  let name: String
  let version: String
  let summary: String?
  let author: String?
  var sharedBy: String? = nil
  let license: String?
  var createdAt: String? = nil
  var publishedAt: String? = nil
  var updatedAt: String? = nil
  var releaseTag: String? = nil
  var stats: RegistryStats? = nil
  var statsIssueURL: URL? = nil
  let previewURL: URL?
  let petConfigURL: URL
  let spritesheetURL: URL
  let petSHA256: String
  let spritesheetSHA256: String
  let petBytes: Int?
  let spritesheetBytes: Int?
}

struct ThemeItem: Identifiable, Hashable {
  let id: String
  let name: String
  let detail: String
  let origin: PackageOrigin
  let imageURL: URL?
  let directoryURL: URL?
  let remote: RegistryTheme?

  var isInstalled: Bool { directoryURL != nil }

  func matches(_ query: String) -> Bool {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !needle.isEmpty else { return true }
    return name.localizedCaseInsensitiveContains(needle)
      || detail.localizedCaseInsensitiveContains(needle)
      || id.localizedCaseInsensitiveContains(needle)
  }
}

struct PetItem: Identifiable, Hashable {
  let id: String
  let name: String
  let detail: String
  let spritesheetURL: URL?
  let directoryURL: URL?
  let remote: RegistryPet?

  var isInstalled: Bool { directoryURL != nil }

  func matches(_ query: String) -> Bool {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !needle.isEmpty else { return true }
    return name.localizedCaseInsensitiveContains(needle)
      || detail.localizedCaseInsensitiveContains(needle)
      || id.localizedCaseInsensitiveContains(needle)
  }
}

enum ThemeStudioError: LocalizedError {
  case engineMissing
  case invalidResponse
  case commandFailed(String)
  case invalidPackage(String)
  case integrityMismatch(String)
  case remoteSourceMissing

  var errorDescription: String? {
    switch self {
    case .engineMissing:
      return "没有找到兼容的 Codex 主题引擎。当前版本可连接已安装的 Dream Skin provider。"
    case .invalidResponse:
      return "状态或社区索引返回了无法识别的数据。"
    case .commandFailed(let message):
      return message
    case .invalidPackage(let message):
      return "主题包无效：\(message)"
    case .integrityMismatch(let file):
      return "完整性校验失败：\(file)"
    case .remoteSourceMissing:
      return "请先在设置中填写 GitHub registry-v1.json 地址。"
    }
  }
}
