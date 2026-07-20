import Foundation

struct RegistryService {
  private let fileManager = FileManager.default
  private let defaults = UserDefaults.standard
  private let etagKey = "communityRegistryETag"

  var stateRoot: URL {
    fileManager.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Application Support/CodexThemeStudio", isDirectory: true)
  }

  var cacheURL: URL {
    stateRoot.appendingPathComponent("registry-cache-v1.json")
  }

  func bundledRegistry() -> RegistryDocument {
    return RegistryDocument(schemaVersion: 1, generatedAt: nil, themes: [], pets: [])
  }

  func cachedRegistry() -> RegistryDocument? {
    guard let data = try? Data(contentsOf: cacheURL) else { return nil }
    return try? decode(data)
  }

  func fetch(from source: String) async throws -> RegistryDocument {
    let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let url = URL(string: trimmed) else {
      throw ThemeStudioError.remoteSourceMissing
    }
    guard url.scheme == "https" else {
      throw ThemeStudioError.invalidPackage("社区源必须使用 HTTPS。")
    }

    var request = URLRequest(url: url)
    request.timeoutInterval = 20
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let etag = defaults.string(forKey: etagKey), !etag.isEmpty {
      request.setValue(etag, forHTTPHeaderField: "If-None-Match")
    }

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw ThemeStudioError.invalidResponse
    }
    if http.statusCode == 304, let cached = cachedRegistry() {
      return cached
    }
    guard (200..<300).contains(http.statusCode), data.count <= 2 * 1024 * 1024 else {
      throw ThemeStudioError.invalidResponse
    }

    let registry = try decode(data)
    try fileManager.createDirectory(at: stateRoot, withIntermediateDirectories: true)
    let temporary = cacheURL.appendingPathExtension("tmp")
    try data.write(to: temporary, options: [.atomic])
    if fileManager.fileExists(atPath: cacheURL.path) {
      try fileManager.removeItem(at: cacheURL)
    }
    try fileManager.moveItem(at: temporary, to: cacheURL)
    if let etag = http.value(forHTTPHeaderField: "ETag") {
      defaults.set(etag, forKey: etagKey)
    }
    return registry
  }

  private func decode(_ data: Data) throws -> RegistryDocument {
    let document = try JSONDecoder().decode(RegistryDocument.self, from: data)
    guard document.schemaVersion == 1 else {
      throw ThemeStudioError.invalidPackage("不支持的 registry schema。")
    }
    guard Set(document.themes.map(\ .id)).count == document.themes.count,
          Set(document.pets.map(\ .id)).count == document.pets.count else {
      throw ThemeStudioError.invalidPackage("registry 中存在重复 ID。")
    }
    return document
  }
}
