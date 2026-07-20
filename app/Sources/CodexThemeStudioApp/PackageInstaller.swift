import CryptoKit
import Foundation
import ImageIO

struct PackageInstaller {
  private let fileManager = FileManager.default
  private let library = LibraryService()
  private let maxConfigBytes = 1 * 1024 * 1024
  private let maxThemeImageBytes = 16 * 1024 * 1024
  private let maxPetImageBytes = 32 * 1024 * 1024

  func install(theme: RegistryTheme) async throws {
    try validateID(theme.id)
    let configData = try await download(
      theme.themeConfigURL,
      maxBytes: min(theme.themeBytes ?? maxConfigBytes, maxConfigBytes)
    )
    let imageData = try await download(
      theme.imageURL,
      maxBytes: min(theme.imageBytes ?? maxThemeImageBytes, maxThemeImageBytes)
    )
    try verify(configData, hash: theme.themeSHA256, name: "theme.json")
    try verify(imageData, hash: theme.imageSHA256, name: theme.imageURL.lastPathComponent)

    let config = try JSONDecoder().decode(ThemeConfig.self, from: configData)
    try validateTheme(config, expectedID: theme.id, expectedVersion: theme.version, imageData: imageData)
    try publish(
      id: theme.id,
      root: library.themesRoot,
      files: ["theme.json": configData, config.image: imageData]
    )
  }

  func install(pet: RegistryPet) async throws {
    try validateID(pet.id)
    let configData = try await download(
      pet.petConfigURL,
      maxBytes: min(pet.petBytes ?? maxConfigBytes, maxConfigBytes)
    )
    let spriteData = try await download(
      pet.spritesheetURL,
      maxBytes: min(pet.spritesheetBytes ?? maxPetImageBytes, maxPetImageBytes)
    )
    try verify(configData, hash: pet.petSHA256, name: "pet.json")
    try verify(spriteData, hash: pet.spritesheetSHA256, name: pet.spritesheetURL.lastPathComponent)

    let config = try JSONDecoder().decode(PetConfig.self, from: configData)
    try validatePet(config, expectedID: pet.id, expectedVersion: pet.version, spriteData: spriteData)
    try publish(
      id: pet.id,
      root: library.petsRoot,
      files: ["pet.json": configData, config.spritesheetPath: spriteData]
    )
  }

  func importTheme(from directory: URL) throws {
    let accessed = directory.startAccessingSecurityScopedResource()
    defer { if accessed { directory.stopAccessingSecurityScopedResource() } }
    let configURL = directory.appendingPathComponent("theme.json")
    let configData = try stableData(from: configURL, maxBytes: maxConfigBytes)
    let config = try JSONDecoder().decode(ThemeConfig.self, from: configData)
    try validateID(config.id)
    let imageData = try stableData(
      from: directory.appendingPathComponent(config.image),
      maxBytes: maxThemeImageBytes
    )
    try validateTheme(config, expectedID: config.id, expectedVersion: nil, imageData: imageData)
    try publish(
      id: config.id,
      root: library.themesRoot,
      files: ["theme.json": configData, config.image: imageData]
    )
  }

  func importPet(from directory: URL) throws {
    let accessed = directory.startAccessingSecurityScopedResource()
    defer { if accessed { directory.stopAccessingSecurityScopedResource() } }
    let configData = try stableData(
      from: directory.appendingPathComponent("pet.json"),
      maxBytes: maxConfigBytes
    )
    let config = try JSONDecoder().decode(PetConfig.self, from: configData)
    try validateID(config.id)
    let spriteData = try stableData(
      from: directory.appendingPathComponent(config.spritesheetPath),
      maxBytes: maxPetImageBytes
    )
    try validatePet(config, expectedID: config.id, expectedVersion: nil, spriteData: spriteData)
    try publish(
      id: config.id,
      root: library.petsRoot,
      files: ["pet.json": configData, config.spritesheetPath: spriteData]
    )
  }

  static func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  private func download(_ url: URL, maxBytes: Int) async throws -> Data {
    guard url.scheme == "https" else {
      throw ThemeStudioError.invalidPackage("资源必须使用 HTTPS。")
    }
    var request = URLRequest(url: url)
    request.timeoutInterval = 30
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse,
          (200..<300).contains(http.statusCode),
          !data.isEmpty,
          data.count <= maxBytes else {
      throw ThemeStudioError.invalidResponse
    }
    return data
  }

  private func verify(_ data: Data, hash: String, name: String) throws {
    let normalized = hash.lowercased()
    guard normalized.count == 64,
          normalized.allSatisfy({ $0.isHexDigit }),
          Self.sha256(data) == normalized else {
      throw ThemeStudioError.integrityMismatch(name)
    }
  }

  private func validateTheme(
    _ config: ThemeConfig,
    expectedID: String,
    expectedVersion: String?,
    imageData: Data
  ) throws {
    guard config.schemaVersion == 1, config.id == expectedID else {
      throw ThemeStudioError.invalidPackage("主题 ID 或 schema 不匹配。")
    }
    if let expectedVersion, config.version != expectedVersion {
      throw ThemeStudioError.invalidPackage("主题版本与社区索引不匹配。")
    }
    guard config.image == URL(fileURLWithPath: config.image).lastPathComponent,
          config.image != "theme.json",
          ["png", "jpg", "jpeg", "webp", "gif"].contains(
            URL(fileURLWithPath: config.image).pathExtension.lowercased()
          ) else {
      throw ThemeStudioError.invalidPackage("背景图路径不安全或格式不受支持。")
    }
    try validateImage(imageData, requiredSize: nil)
  }

  private func validatePet(
    _ config: PetConfig,
    expectedID: String,
    expectedVersion: String?,
    spriteData: Data
  ) throws {
    guard config.id == expectedID, config.spriteVersionNumber == 2 else {
      throw ThemeStudioError.invalidPackage("宠物 ID 或图集版本不匹配。")
    }
    if let expectedVersion, config.version != expectedVersion {
      throw ThemeStudioError.invalidPackage("宠物版本与社区索引不匹配。")
    }
    guard config.spritesheetPath == "spritesheet.webp" else {
      throw ThemeStudioError.invalidPackage("V2 宠物图集必须命名为 spritesheet.webp。")
    }
    try validateImage(spriteData, requiredSize: (1536, 2288))
  }

  private func validateImage(_ data: Data, requiredSize: (Int, Int)?) throws {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int,
          width > 0, height > 0,
          width <= 16_384, height <= 16_384,
          width * height <= 50_000_000 else {
      throw ThemeStudioError.invalidPackage("图片尺寸或编码无效。")
    }
    if let requiredSize, (width, height) != requiredSize {
      throw ThemeStudioError.invalidPackage(
        "宠物图集尺寸必须为 \(requiredSize.0) × \(requiredSize.1)。"
      )
    }
  }

  private func stableData(from url: URL, maxBytes: Int) throws -> Data {
    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
    guard values.isRegularFile == true,
          let size = values.fileSize,
          size > 0,
          size <= maxBytes else {
      throw ThemeStudioError.invalidPackage("文件不存在、为空或过大。")
    }
    return try Data(contentsOf: url, options: [.mappedIfSafe, .uncached])
  }

  private func validateID(_ id: String) throws {
    guard id.range(of: "^[a-z0-9][a-z0-9-]{1,63}$", options: .regularExpression) != nil else {
      throw ThemeStudioError.invalidPackage("ID 必须是 2～64 位小写 kebab-case。")
    }
  }

  private func publish(id: String, root: URL, files: [String: Data]) throws {
    try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    let stage = root.appendingPathComponent(".install-\(UUID().uuidString)", isDirectory: true)
    let destination = root.appendingPathComponent(id, isDirectory: true)
    let backup = root.appendingPathComponent(".backup-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: stage, withIntermediateDirectories: false)
    do {
      for (name, data) in files {
        guard name == URL(fileURLWithPath: name).lastPathComponent else {
          throw ThemeStudioError.invalidPackage("包内文件路径不安全。")
        }
        try data.write(to: stage.appendingPathComponent(name), options: [.atomic])
      }
      if fileManager.fileExists(atPath: destination.path) {
        try fileManager.moveItem(at: destination, to: backup)
      }
      try fileManager.moveItem(at: stage, to: destination)
      if fileManager.fileExists(atPath: backup.path) {
        try fileManager.removeItem(at: backup)
      }
    } catch {
      try? fileManager.removeItem(at: stage)
      if fileManager.fileExists(atPath: backup.path),
         !fileManager.fileExists(atPath: destination.path) {
        try? fileManager.moveItem(at: backup, to: destination)
      }
      throw error
    }
  }
}
