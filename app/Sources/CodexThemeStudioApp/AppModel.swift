import AppKit
import Foundation
import ServiceManagement
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
  static let shared = AppModel()

  @Published var status = EngineStatus.unavailable
  @Published var activeThemeID: String?
  @Published var themes: [ThemeItem] = []
  @Published var pets: [PetItem] = []
  @Published var scope: LibraryScope = .themes
  @Published var searchText = ""
  @Published var selectedThemeID: String?
  @Published var selectedPetID: String?
  @Published var previewTheme: ThemeItem?
  @Published var isBusy = false
  @Published var bannerMessage: String?
  @Published var bannerIsError = false
  @Published var showSettings = false
  @Published var showImporter = false
  @Published var showRestartConfirmation = false
  @Published var pendingTheme: ThemeItem?
  @Published var loginEnabled = false
  @Published var registryURL: String {
    didSet { UserDefaults.standard.set(registryURL, forKey: Self.registryKey) }
  }

  private static let registryKey = "communityRegistryURL"
  private static let defaultRegistryURL = "https://raw.githubusercontent.com/983033995/Codex-Theme-Gallery/main/registry/registry-v1.json"
  private static let loginPreferenceKey = "launchAtLoginPreference"
  private let engine = EngineService()
  private let library = LibraryService()
  private let registry = RegistryService()
  private let installer = PackageInstaller()
  private let designPreviewMode = ProcessInfo.processInfo.arguments.contains("--design-qa")
  private var remoteRegistry: RegistryDocument
  private var monitorTask: Task<Void, Never>?
  private var bannerDismissTask: Task<Void, Never>?
  private var autoRepairAttempted = false

  init() {
    registryURL = UserDefaults.standard.string(forKey: Self.registryKey)
      ?? Self.defaultRegistryURL
    remoteRegistry = registry.cachedRegistry() ?? registry.bundledRegistry()
    loginEnabled = SMAppService.mainApp.status == .enabled
    reloadLibraries()
    monitorTask = Task { [weak self] in
      await self?.refreshAll(deep: true)
      await self?.autoRepairIfNeeded()
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 8_000_000_000)
        await self?.refreshStatus(deep: false)
        await self?.autoRepairIfNeeded()
      }
    }
  }

  deinit {
    monitorTask?.cancel()
    bannerDismissTask?.cancel()
  }

  var filteredThemes: [ThemeItem] {
    themes.filter { theme in
      theme.matches(searchText) && (scope != .installed || theme.isInstalled)
    }
  }

  var filteredPets: [PetItem] {
    pets.filter { pet in
      pet.matches(searchText) && (scope != .installed || pet.isInstalled)
    }
  }

  var selectedTheme: ThemeItem? {
    let visible = filteredThemes
    return visible.first(where: { $0.id == selectedThemeID }) ?? visible.first
  }

  var selectedPet: PetItem? {
    let visible = filteredPets
    return visible.first(where: { $0.id == selectedPetID }) ?? visible.first
  }

  var menuBarSymbol: String {
    if status.isHealthy { return "paintpalette.fill" }
    if status.needsRepair { return "paintpalette.fill" }
    return "paintpalette"
  }

  var statusColorName: String {
    if status.isHealthy { return "healthy" }
    if status.needsRepair { return "warning" }
    return "idle"
  }

  func refreshAll(deep: Bool) async {
    reloadLibraries()
    await refreshStatus(deep: deep)
  }

  func refreshStatus(deep: Bool) async {
    if designPreviewMode {
      activeThemeID = library.loadActiveThemeID()
      status = EngineStatus(
        session: "active",
        port: 9341,
        injectorAlive: true,
        cdpOk: true,
        codexRunning: true,
        themeName: themes.first(where: { $0.id == activeThemeID })?.name ?? ""
      )
      selectedThemeID = activeThemeID ?? themes.first?.id
      return
    }
    do {
      status = try await engine.status(deep: deep)
      activeThemeID = library.loadActiveThemeID()
      if let activeThemeID, themes.contains(where: { $0.id == activeThemeID }) {
        selectedThemeID = activeThemeID
      } else if selectedThemeID == nil {
        selectedThemeID = themes.first?.id
      }
    } catch {
      status = .unavailable
      if deep { show(error: error) }
    }
  }

  func refreshCommunity() {
    Task {
      await performBusy {
        remoteRegistry = try await registry.fetch(from: registryURL)
        reloadLibraries()
        show(message: "社区主题与宠物列表已更新。")
      }
    }
  }

  func requestApplySelectedTheme() {
    guard let theme = selectedTheme else { return }
    requestApply(theme)
  }

  func requestApply(_ theme: ThemeItem) {
    pendingTheme = theme
    if status.needsRepair {
      showRestartConfirmation = true
    } else {
      applyPendingTheme()
    }
  }

  func applyPendingTheme() {
    guard let theme = pendingTheme else { return }
    pendingTheme = nil
    showRestartConfirmation = false
    Task {
      await performBusy {
        var target = theme
        if !target.isInstalled {
          guard let remote = target.remote else {
            throw ThemeStudioError.invalidPackage("主题没有可安装的来源。")
          }
          try await installer.install(theme: remote)
          reloadLibraries()
          guard let installed = themes.first(where: { $0.id == theme.id }) else {
            throw ThemeStudioError.invalidPackage("主题下载后没有出现在本地主题库中。")
          }
          target = installed
        }
        try await engine.switchTheme(id: target.id)
        activeThemeID = target.id
        selectedThemeID = target.id
        themes.sort { left, right in
          if left.id == target.id { return true }
          if right.id == target.id { return false }
          return left.name.localizedStandardCompare(right.name) == .orderedAscending
        }
        show(message: "已应用：\(target.name)")
        await refreshStatus(deep: true)
      }
    }
  }

  func repairEngine() {
    Task {
      await performBusy {
        try await engine.repair(restartExisting: status.codexRunning)
        show(message: "Theme Studio 已恢复。")
        await refreshStatus(deep: true)
      }
    }
  }

  func installSelectedPet() {
    guard let pet = selectedPet, !pet.isInstalled, let remote = pet.remote else { return }
    Task {
      await performBusy {
        try await installer.install(pet: remote)
        reloadLibraries()
        selectedPetID = pet.id
        show(message: "宠物已安装：\(pet.name)")
      }
    }
  }

  func importPackage(from directory: URL) {
    Task {
      await performBusy {
        if scope == .pets {
          try installer.importPet(from: directory)
          show(message: "宠物包已导入。")
        } else {
          try installer.importTheme(from: directory)
          show(message: "主题包已导入。")
        }
        reloadLibraries()
      }
    }
  }

  func moveSelection(_ direction: MoveCommandDirection) {
    switch scope {
    case .themes, .installed:
      let visible = filteredThemes
      guard !visible.isEmpty else { return }
      let index = visible.firstIndex(where: { $0.id == selectedThemeID }) ?? 0
      let next = direction == .down ? min(index + 1, visible.count - 1) : max(index - 1, 0)
      selectedThemeID = visible[next].id
    case .pets:
      let visible = filteredPets
      guard !visible.isEmpty else { return }
      let index = visible.firstIndex(where: { $0.id == selectedPetID }) ?? 0
      let next = direction == .down ? min(index + 1, visible.count - 1) : max(index - 1, 0)
      selectedPetID = visible[next].id
    }
  }

  func selectTheme(at index: Int) {
    guard filteredThemes.indices.contains(index) else { return }
    selectedThemeID = filteredThemes[index].id
  }

  func previewSelectedTheme() {
    previewTheme = selectedTheme
  }

  func openCodex() {
    engine.openCodex()
  }

  func openStateFolder() {
    NSWorkspace.shared.open(library.stateRoot)
  }

  func openRepository() {
    guard let source = URL(string: registryURL), let host = source.host else {
      show(message: "项目尚未配置 GitHub 社区仓库。")
      return
    }
    let parts = source.pathComponents.filter { $0 != "/" }
    let repositoryURL: URL?
    if host == "raw.githubusercontent.com", parts.count >= 2 {
      repositoryURL = URL(string: "https://github.com/\(parts[0])/\(parts[1])")
    } else if host == "github.com", parts.count >= 2 {
      repositoryURL = URL(string: "https://github.com/\(parts[0])/\(parts[1])")
    } else {
      repositoryURL = nil
    }
    guard let repositoryURL else {
      show(message: "当前社区源不是可识别的 GitHub 仓库地址。")
      return
    }
    NSWorkspace.shared.open(repositoryURL)
  }

  func updateLoginItem(_ enabled: Bool) {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      loginEnabled = SMAppService.mainApp.status == .enabled
      UserDefaults.standard.set(enabled, forKey: Self.loginPreferenceKey)
      show(message: loginEnabled ? "已开启登录时启动。" : "已关闭登录时启动。")
    } catch {
      loginEnabled = SMAppService.mainApp.status == .enabled
      show(error: error)
    }
  }

  func ensureLoginItemDefault() {
    let shouldLaunchAtLogin = UserDefaults.standard.object(forKey: Self.loginPreferenceKey) as? Bool ?? true
    guard shouldLaunchAtLogin, SMAppService.mainApp.status != .enabled else {
      loginEnabled = SMAppService.mainApp.status == .enabled
      return
    }
    do {
      try SMAppService.mainApp.register()
      loginEnabled = SMAppService.mainApp.status == .enabled
    } catch {
      loginEnabled = false
    }
  }

  func retireLegacyManagerIfNeeded() {
    let retired = LegacyManagerService().retireRunningManager()
    guard retired > 0 else { return }
    show(message: "已接管旧 Dream Skin 管理器，只保留 Theme Studio 菜单栏入口。")
  }

  func quit() {
    NSApplication.shared.terminate(nil)
  }

  private func autoRepairIfNeeded() async {
    guard !designPreviewMode else { return }
    if status.isHealthy {
      autoRepairAttempted = false
      return
    }
    guard status.codexRunning else {
      autoRepairAttempted = false
      return
    }
    guard StartupPolicy.shouldAutoRepair(
      status: status,
      attempted: autoRepairAttempted,
      busy: isBusy
    ) else { return }

    autoRepairAttempted = true
    isBusy = true
    defer { isBusy = false }
    do {
      try await engine.repair(restartExisting: true)
      show(message: "Theme Studio 已自动恢复主题守护。")
      await refreshStatus(deep: true)
    } catch {
      show(error: error)
    }
  }

  private func reloadLibraries() {
    activeThemeID = library.loadActiveThemeID()
    themes = library.mergeThemes(
      installed: library.loadThemes(),
      remote: remoteRegistry.themes
    )
    if let activeThemeID {
      themes.sort { left, right in
        if left.id == activeThemeID { return true }
        if right.id == activeThemeID { return false }
        return left.name.localizedStandardCompare(right.name) == .orderedAscending
      }
    }
    pets = library.mergePets(
      installed: library.loadPets(),
      remote: remoteRegistry.pets
    )
    if selectedThemeID == nil {
      selectedThemeID = activeThemeID ?? themes.first?.id
    }
    if selectedPetID == nil { selectedPetID = pets.first?.id }
  }

  private func performBusy(_ operation: () async throws -> Void) async {
    guard !isBusy else { return }
    isBusy = true
    defer { isBusy = false }
    do {
      try await operation()
    } catch {
      show(error: error)
    }
  }

  private func show(message: String) {
    bannerIsError = false
    bannerMessage = message
    scheduleBannerDismissal()
  }

  private func show(error: Error) {
    bannerIsError = true
    bannerMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    scheduleBannerDismissal()
  }

  private func scheduleBannerDismissal() {
    bannerDismissTask?.cancel()
    bannerDismissTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 2_800_000_000)
      guard !Task.isCancelled else { return }
      self?.bannerMessage = nil
    }
  }
}
