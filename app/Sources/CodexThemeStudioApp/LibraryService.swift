import Foundation

struct LibraryService {
  private let fileManager = FileManager.default

  var stateRoot: URL {
    fileManager.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Application Support/CodexDreamSkinStudio", isDirectory: true)
  }

  var themesRoot: URL {
    stateRoot.appendingPathComponent("themes", isDirectory: true)
  }

  var petsRoot: URL {
    fileManager.homeDirectoryForCurrentUser
      .appendingPathComponent(".codex/pets", isDirectory: true)
  }

  func loadActiveThemeID() -> String? {
    let configURL = stateRoot
      .appendingPathComponent("theme", isDirectory: true)
      .appendingPathComponent("theme.json")
    guard
      let data = try? Data(contentsOf: configURL),
      let config = try? JSONDecoder().decode(ThemeConfig.self, from: data),
      config.schemaVersion == 1
    else { return nil }
    return config.id
  }

  func loadThemes() -> [ThemeItem] {
    guard let directories = try? fileManager.contentsOfDirectory(
      at: themesRoot,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    ) else { return [] }

    return directories.compactMap { directory in
      guard (try? directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
        return nil
      }
      let configURL = directory.appendingPathComponent("theme.json")
      guard
        let data = try? Data(contentsOf: configURL),
        let config = try? JSONDecoder().decode(ThemeConfig.self, from: data),
        config.schemaVersion == 1,
        config.id == directory.lastPathComponent
      else { return nil }

      let imageURL = directory.appendingPathComponent(config.image)
      let origin: PackageOrigin = config.id.hasPrefix("preset-") ? .bundled : .local
      return ThemeItem(
        id: config.id,
        name: config.name,
        detail: config.tagline ?? origin.rawValue,
        origin: origin,
        imageURL: fileManager.fileExists(atPath: imageURL.path) ? imageURL : nil,
        directoryURL: directory,
        remote: nil
      )
    }
    .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  func loadPets() -> [PetItem] {
    guard let directories = try? fileManager.contentsOfDirectory(
      at: petsRoot,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    ) else { return [] }

    return directories.compactMap { directory in
      guard (try? directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
        return nil
      }
      let configURL = directory.appendingPathComponent("pet.json")
      guard
        let data = try? Data(contentsOf: configURL),
        let config = try? JSONDecoder().decode(PetConfig.self, from: data),
        config.id == directory.lastPathComponent,
        config.spriteVersionNumber == 2
      else { return nil }
      let spriteURL = directory.appendingPathComponent(config.spritesheetPath)
      return PetItem(
        id: config.id,
        name: config.displayName,
        detail: config.description ?? "已安装宠物",
        spritesheetURL: fileManager.fileExists(atPath: spriteURL.path) ? spriteURL : nil,
        directoryURL: directory,
        remote: nil
      )
    }
    .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  func mergeThemes(installed: [ThemeItem], remote: [RegistryTheme]) -> [ThemeItem] {
    var table = Dictionary(uniqueKeysWithValues: installed.map { ($0.id, $0) })
    for theme in remote where table[theme.id] == nil {
      table[theme.id] = ThemeItem(
        id: theme.id,
        name: theme.name,
        detail: communityDetail(
          summary: theme.summary,
          sharedBy: theme.sharedBy,
          stats: theme.stats,
          fallback: "社区主题"
        ),
        origin: .community,
        imageURL: theme.previewURL,
        directoryURL: nil,
        remote: theme
      )
    }
    return table.values.sorted { left, right in
      if left.isInstalled != right.isInstalled { return left.isInstalled }
      return left.name.localizedStandardCompare(right.name) == .orderedAscending
    }
  }

  func mergePets(installed: [PetItem], remote: [RegistryPet]) -> [PetItem] {
    var table = Dictionary(uniqueKeysWithValues: installed.map { ($0.id, $0) })
    for pet in remote {
      if let local = table[pet.id] {
        // 已安装副本继续使用本地资源，但保留社区统计与收藏入口。
        table[pet.id] = PetItem(
          id: local.id,
          name: local.name,
          detail: local.detail,
          spritesheetURL: local.spritesheetURL,
          directoryURL: local.directoryURL,
          remote: pet
        )
      } else {
        table[pet.id] = PetItem(
          id: pet.id,
          name: pet.name,
          detail: communityDetail(
            summary: pet.summary,
            sharedBy: pet.sharedBy,
            stats: pet.stats,
            fallback: "社区宠物"
          ),
          spritesheetURL: pet.previewURL,
          directoryURL: nil,
          remote: pet
        )
      }
    }
    return table.values.sorted { left, right in
      if left.isInstalled != right.isInstalled { return left.isInstalled }
      return left.name.localizedStandardCompare(right.name) == .orderedAscending
    }
  }

  private func communityDetail(
    summary: String?,
    sharedBy: String?,
    stats: RegistryStats?,
    fallback: String
  ) -> String {
    var parts = [summary?.trimmingCharacters(in: .whitespacesAndNewlines)]
      .compactMap { value in value?.isEmpty == false ? value : nil }
    if let sharedBy, !sharedBy.isEmpty { parts.append("@\(sharedBy)") }
    if let stats { parts.append("↓\(stats.downloads)  ♥\(stats.favorites)") }
    return parts.isEmpty ? fallback : parts.joined(separator: " · ")
  }
}
