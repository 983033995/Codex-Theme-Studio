import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

private enum PanelPalette {
  static let background = LinearGradient(
    colors: [
      Color(red: 0.075, green: 0.088, blue: 0.098),
      Color(red: 0.045, green: 0.058, blue: 0.066)
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )
  static let surface = Color.white.opacity(0.055)
  static let surfaceStrong = Color.white.opacity(0.09)
  static let line = Color.white.opacity(0.11)
  static let text = Color.white.opacity(0.95)
  static let muted = Color.white.opacity(0.54)
  static let accent = Color(red: 0.42, green: 0.92, blue: 0.58)
  static let blue = Color(red: 0.35, green: 0.64, blue: 1.0)
  static let warning = Color(red: 1.0, green: 0.69, blue: 0.28)
  static let error = Color(red: 1.0, green: 0.34, blue: 0.35)
}

struct ThemeStudioPanel: View {
  @EnvironmentObject private var model: AppModel
  @FocusState private var searchFocused: Bool

  var body: some View {
    ZStack {
      PanelPalette.background
        .ignoresSafeArea()

      VStack(spacing: 0) {
        searchHeader
        scopePicker
        content
        statusFooter
        actionBar
      }
    }
    .overlay(alignment: .bottom) {
      if let message = model.bannerMessage {
        messageBanner(message)
          .padding(.horizontal, 14)
          .padding(.bottom, 100)
          .transition(.move(edge: .bottom).combined(with: .opacity))
          .zIndex(20)
          .onTapGesture { model.bannerMessage = nil }
      }
    }
    .onMoveCommand { direction in
      if direction == .up || direction == .down {
        model.moveSelection(direction)
      }
    }
    .onAppear {
      searchFocused = true
      Task { await model.refreshAll(deep: true) }
    }
    .sheet(item: $model.previewTheme) { theme in
      ThemePreviewSheet(theme: theme)
    }
    .sheet(isPresented: $model.showSettings) {
      SettingsSheet()
        .environmentObject(model)
    }
    .fileImporter(
      isPresented: $model.showImporter,
      allowedContentTypes: [.folder],
      allowsMultipleSelection: false
    ) { result in
      if case .success(let urls) = result, let directory = urls.first {
        model.importPackage(from: directory)
      }
    }
    .alert("重启 Codex 并应用主题？", isPresented: $model.showRestartConfirmation) {
      Button("取消", role: .cancel) { model.pendingTheme = nil }
      Button("重启并应用") { model.applyPendingTheme() }
    } message: {
      Text("当前 Codex 没有兼容主题引擎的调试通道。应用会安全关闭并重新打开 Codex，不会修改官方应用文件或项目数据。")
    }
    .overlay {
      keyboardShortcuts
    }
  }

  private var searchHeader: some View {
    HStack(spacing: 12) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(PanelPalette.muted)

      TextField("搜索主题或宠物…", text: $model.searchText)
        .textFieldStyle(.plain)
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(PanelPalette.text)
        .focused($searchFocused)

      HStack(spacing: 7) {
        Circle()
          .fill(model.status.isHealthy ? PanelPalette.accent : (model.status.needsRepair ? PanelPalette.warning : PanelPalette.muted))
          .frame(width: 9, height: 9)
          .shadow(color: model.status.isHealthy ? PanelPalette.accent.opacity(0.6) : .clear, radius: 4)
        Text(model.status.codexRunning ? "Codex 在线" : "Codex 未打开")
          .font(.system(size: 12.5, weight: .medium))
          .foregroundStyle(PanelPalette.muted)
      }
    }
    .padding(.horizontal, 16)
    .frame(height: 52)
    .background(PanelPalette.surface)
    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 13, style: .continuous)
        .stroke(PanelPalette.line, lineWidth: 1)
    }
    .padding(.horizontal, 14)
    .padding(.top, 14)
    .padding(.bottom, 10)
  }

  private var scopePicker: some View {
    HStack(spacing: 5) {
      ForEach(LibraryScope.allCases) { scope in
        Button {
          model.scope = scope
        } label: {
          HStack(spacing: 7) {
            Image(systemName: scope.systemImage)
            Text(scope.rawValue)
          }
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(model.scope == scope ? PanelPalette.text : PanelPalette.muted)
          .frame(maxWidth: .infinity)
          .frame(height: 36)
          .background(model.scope == scope ? PanelPalette.surfaceStrong : Color.clear)
          .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
      }
    }
    .padding(5)
    .background(PanelPalette.surface)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(PanelPalette.line, lineWidth: 1)
    }
    .padding(.horizontal, 14)
    .padding(.bottom, 10)
  }

  @ViewBuilder
  private var content: some View {
    if model.scope == .pets {
      petList
    } else {
      themeList
    }
  }

  private var themeList: some View {
    ScrollViewReader { proxy in
      ScrollView(.vertical, showsIndicators: false) {
        LazyVStack(spacing: 0) {
          if model.filteredThemes.isEmpty {
            EmptyLibraryView(
              icon: "paintpalette",
              title: "没有找到主题",
              subtitle: "换个关键词，或从本地导入主题包。"
            )
          } else {
            ForEach(Array(model.filteredThemes.enumerated()), id: \.element.id) { index, theme in
              ThemeLibraryRow(
                theme: theme,
                index: index,
                selected: model.selectedTheme?.id == theme.id,
                active: model.activeThemeID == theme.id,
                select: { model.selectedThemeID = theme.id },
                apply: { model.requestApply(theme) }
              )
              .id(theme.id)
            }
          }
        }
        .padding(.horizontal, 14)
      }
      .onChange(of: model.selectedThemeID) { id in
        guard let id else { return }
        withAnimation(.easeOut(duration: 0.18)) {
          proxy.scrollTo(id, anchor: .center)
        }
      }
    }
    .frame(maxHeight: .infinity)
  }

  private var petList: some View {
    ScrollView(.vertical, showsIndicators: false) {
      LazyVStack(spacing: 0) {
        if model.filteredPets.isEmpty {
          EmptyLibraryView(
            icon: "pawprint",
            title: "还没有宠物",
            subtitle: "刷新社区源，或导入 Codex V2 宠物包。"
          )
        } else {
          ForEach(model.filteredPets) { pet in
            PetLibraryRow(
              pet: pet,
              selected: model.selectedPet?.id == pet.id,
              select: { model.selectedPetID = pet.id },
              install: { model.installSelectedPet() },
              favorite: { model.favorite(pet) }
            )
          }
        }
      }
      .padding(.horizontal, 14)
    }
    .frame(maxHeight: .infinity)
  }

  private var statusFooter: some View {
    Button {
      if model.status.needsRepair || !model.status.isHealthy {
        model.repairEngine()
      }
    } label: {
      HStack(spacing: 10) {
        Circle()
          .fill(model.status.isHealthy ? PanelPalette.accent : (model.status.needsRepair ? PanelPalette.warning : PanelPalette.muted))
          .frame(width: 10, height: 10)
        Text(model.status.healthTitle)
          .font(.system(size: 12.5, weight: .medium))
          .foregroundStyle(model.status.needsRepair ? PanelPalette.warning : PanelPalette.muted)
        Spacer()
        if model.isBusy {
          ProgressView()
            .controlSize(.small)
        } else {
          Image(systemName: "chevron.right")
            .foregroundStyle(PanelPalette.muted)
        }
      }
      .padding(.horizontal, 16)
      .frame(height: 43)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(model.isBusy || model.status.isHealthy)
    .background(PanelPalette.surface)
    .overlay(alignment: .top) { Divider().overlay(PanelPalette.line) }
  }

  private var actionBar: some View {
    HStack(spacing: 0) {
      ActionButton(
        icon: model.scope == .pets ? "square.and.arrow.down" : "checkmark.circle",
        title: model.scope == .pets ? (model.selectedPet?.isInstalled == true ? "已安装" : "安装宠物") : "应用主题",
        shortcut: model.scope == .pets ? nil : "↵",
        enabled: !model.isBusy && (model.scope != .pets || model.selectedPet?.isInstalled == false)
      ) {
        if model.scope == .pets { model.installSelectedPet() }
        else { model.requestApplySelectedTheme() }
      }

      ActionDivider()

      ActionButton(icon: "eye", title: "预览", shortcut: "Space", enabled: model.selectedTheme != nil) {
        model.previewSelectedTheme()
      }

      ActionDivider()

      Menu {
        Button("刷新社区列表", systemImage: "arrow.clockwise") { model.refreshCommunity() }
        Button("导入本地包…", systemImage: "square.and.arrow.down") { model.showImporter = true }
        Button("打开数据目录", systemImage: "folder") { model.openStateFolder() }
        Divider()
        Button("设置…", systemImage: "gearshape") { model.showSettings = true }
        Button("退出 Theme Studio", systemImage: "power", role: .destructive) { model.quit() }
      } label: {
        HStack(spacing: 7) {
          Image(systemName: "ellipsis.circle")
          Text("更多")
          ShortcutBadge(text: "⌘K")
        }
        .font(.system(size: 13.5, weight: .semibold))
        .foregroundStyle(PanelPalette.text)
        .frame(maxWidth: .infinity, minHeight: 47)
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)

      ActionDivider()

      Button {
        model.openRepository()
      } label: {
        GitHubMarkView()
          .foregroundStyle(PanelPalette.text)
          .frame(width: 48)
          .frame(minHeight: 47)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .help("打开 GitHub 项目")
    }
    .background(PanelPalette.surfaceStrong)
    .overlay(alignment: .top) { Divider().overlay(PanelPalette.line) }
  }

  private var keyboardShortcuts: some View {
    VStack {
      Button("") { model.requestApplySelectedTheme() }
        .keyboardShortcut(.return, modifiers: [])
      Button("") { model.previewSelectedTheme() }
        .keyboardShortcut(.space, modifiers: [])
      Button("") { model.showSettings = true }
        .keyboardShortcut("k", modifiers: .command)
      ForEach(0..<5, id: \.self) { index in
        Button("") { model.selectTheme(at: index) }
          .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
      }
    }
    .frame(width: 0, height: 0)
    .opacity(0)
    .allowsHitTesting(false)
  }

  private func messageBanner(_ message: String) -> some View {
    HStack(spacing: 9) {
      Image(systemName: model.bannerIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
      Text(message)
        .lineLimit(2)
      Spacer(minLength: 0)
    }
    .font(.system(size: 12.5, weight: .semibold))
    .foregroundStyle(.white)
    .padding(.horizontal, 13)
    .padding(.vertical, 10)
    .background(model.bannerIsError ? PanelPalette.error.opacity(0.94) : Color.black.opacity(0.86))
    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    .shadow(color: .black.opacity(0.35), radius: 14, y: 7)
  }
}

private struct ThemeLibraryRow: View {
  let theme: ThemeItem
  let index: Int
  let selected: Bool
  let active: Bool
  let select: () -> Void
  let apply: () -> Void
  @State private var hovering = false

  var body: some View {
    VStack(spacing: 0) {
      Button(action: select) {
        HStack(spacing: 12) {
          ThemeImage(url: theme.imageURL)
            .frame(width: 64, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
              Text(theme.name)
                .font(.system(size: 15.5, weight: .semibold))
                .foregroundStyle(PanelPalette.text)
              Circle()
                .fill(active ? PanelPalette.accent : PanelPalette.blue)
                .frame(width: 7, height: 7)
              Text(active ? "已启用" : (theme.isInstalled ? "未启用" : "待下载"))
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(active ? PanelPalette.accent : PanelPalette.muted)
            }
            Text(theme.origin.rawValue)
              .font(.system(size: 12.5))
              .foregroundStyle(PanelPalette.muted)
          }

          Spacer()
          ShortcutBadge(text: "⌘\(index + 1)")
        }
        .padding(.horizontal, 10)
        .frame(height: 60)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .onHover { hovering = $0 }

      if selected {
        ThemeImage(url: theme.imageURL)
          .frame(height: 154)
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
          .padding(.horizontal, 9)
          .padding(.bottom, 9)
          .onTapGesture(perform: apply)
      }
    }
    .background(selected ? PanelPalette.accent.opacity(0.055) : (hovering ? PanelPalette.surface : Color.clear))
    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 13, style: .continuous)
        .stroke(selected ? PanelPalette.accent : Color.clear, lineWidth: 1.5)
    }
    .overlay(alignment: .bottom) {
      if !selected {
        Rectangle()
          .fill(PanelPalette.line)
          .frame(height: 1)
          .padding(.leading, 86)
      }
    }
    .padding(.bottom, 3)
  }
}

private struct PetLibraryRow: View {
  let pet: PetItem
  let selected: Bool
  let select: () -> Void
  let install: () -> Void
  let favorite: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: select) {
      HStack(spacing: 13) {
        PetThumbnail(url: pet.spritesheetURL)
          .frame(width: 64, height: 64)
          .background(PanelPalette.surface)
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        VStack(alignment: .leading, spacing: 5) {
          Text(pet.name)
            .font(.system(size: 15.5, weight: .semibold))
            .foregroundStyle(PanelPalette.text)
          Text(pet.detail)
            .font(.system(size: 12.5))
            .foregroundStyle(PanelPalette.muted)
            .lineLimit(2)
          if let stats = pet.remote?.stats {
            HStack(spacing: 7) {
              Label("\(stats.downloads)", systemImage: "arrow.down.circle")
              Label("\(stats.favorites)", systemImage: "star")
              if pet.remote?.statsIssueURL != nil {
                Button(action: favorite) {
                  Label("收藏", systemImage: "heart")
                }
                .buttonStyle(.plain)
                .foregroundStyle(PanelPalette.accent)
                .help("在 GitHub 收藏页添加 ❤️ 或 👍")
              }
            }
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(PanelPalette.muted)
          }
        }
        Spacer()
        if pet.isInstalled {
          Label("已安装", systemImage: "checkmark.circle.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(PanelPalette.accent)
        } else if selected {
          Button("安装", action: install)
            .buttonStyle(.borderedProminent)
            .tint(PanelPalette.accent)
        }
      }
      .padding(11)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .background(selected ? PanelPalette.surfaceStrong : (hovering ? PanelPalette.surface : Color.clear))
    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 13, style: .continuous)
        .stroke(selected ? PanelPalette.accent.opacity(0.75) : Color.clear, lineWidth: 1)
    }
    .onHover { hovering = $0 }
    .padding(.bottom, 5)
  }
}

private struct ThemeImage: View {
  let url: URL?

  var body: some View {
    Group {
      if let url, url.isFileURL, let image = NSImage(contentsOf: url) {
        Image(nsImage: image)
          .resizable()
          .scaledToFill()
      } else if let url {
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let image): image.resizable().scaledToFill()
          case .failure: fallback
          default: ProgressView().controlSize(.small)
          }
        }
      } else {
        fallback
      }
    }
    .clipped()
  }

  private var fallback: some View {
    ZStack {
      PanelPalette.surfaceStrong
      Image(systemName: "photo")
        .foregroundStyle(PanelPalette.muted)
    }
  }
}

private struct PetThumbnail: View {
  let url: URL?

  var body: some View {
    Group {
      if let url, url.isFileURL, let image = firstFrame(from: url) {
        Image(nsImage: image)
          .resizable()
          .scaledToFit()
      } else if let url {
        AsyncImage(url: url) { phase in
          if let image = phase.image { image.resizable().scaledToFit() }
          else { ProgressView().controlSize(.small) }
        }
      } else {
        Image(systemName: "pawprint.fill")
          .font(.system(size: 25))
          .foregroundStyle(PanelPalette.muted)
      }
    }
    .padding(5)
  }

  private func firstFrame(from url: URL) -> NSImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let sheet = CGImageSourceCreateImageAtIndex(source, 0, nil),
          sheet.width >= 192, sheet.height >= 208,
          let frame = sheet.cropping(to: CGRect(x: 0, y: sheet.height - 208, width: 192, height: 208))
    else { return nil }
    return NSImage(cgImage: frame, size: NSSize(width: 192, height: 208))
  }
}

private struct ActionButton: View {
  let icon: String
  let title: String
  let shortcut: String?
  let enabled: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 7) {
        Image(systemName: icon)
          .foregroundStyle(enabled ? PanelPalette.accent : PanelPalette.muted)
        Text(title)
        if let shortcut { ShortcutBadge(text: shortcut) }
      }
      .font(.system(size: 13.5, weight: .semibold))
      .foregroundStyle(enabled ? PanelPalette.text : PanelPalette.muted)
      .frame(maxWidth: .infinity, minHeight: 47)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
  }
}

private struct ActionDivider: View {
  var body: some View {
    Rectangle()
      .fill(PanelPalette.line)
      .frame(width: 1, height: 24)
  }
}

private struct ShortcutBadge: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.system(size: 11.5, weight: .medium, design: .rounded))
      .foregroundStyle(PanelPalette.muted)
      .padding(.horizontal, 7)
      .padding(.vertical, 4)
      .background(PanelPalette.surfaceStrong)
      .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
  }
}

private struct GitHubMarkView: View {
  private var image: NSImage? {
    let candidates = [
      Bundle.main.resourceURL?.appendingPathComponent("GitHubMark.png"),
      URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("macos/app/Assets/GitHubMark.png")
    ].compactMap { $0 }
    guard let image = candidates.lazy.compactMap({ NSImage(contentsOf: $0) }).first else { return nil }
    image.isTemplate = true
    return image
  }

  var body: some View {
    Group {
      if let image {
        Image(nsImage: image)
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
      } else {
        Image(systemName: "arrow.triangle.branch")
      }
    }
    .frame(width: 21, height: 21)
  }
}

private struct EmptyLibraryView: View {
  let icon: String
  let title: String
  let subtitle: String

  var body: some View {
    VStack(spacing: 10) {
      Image(systemName: icon)
        .font(.system(size: 28))
        .foregroundStyle(PanelPalette.muted)
      Text(title)
        .font(.headline)
        .foregroundStyle(PanelPalette.text)
      Text(subtitle)
        .font(.subheadline)
        .foregroundStyle(PanelPalette.muted)
    }
    .frame(maxWidth: .infinity, minHeight: 250)
  }
}

private struct ThemePreviewSheet: View {
  let theme: ThemeItem
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text(theme.name).font(.title3.bold())
          Text(theme.detail).foregroundStyle(.secondary)
        }
        Spacer()
        Button("关闭") { dismiss() }
      }
      .padding(18)
      ThemeImage(url: theme.imageURL)
        .frame(width: 720, height: 405)
    }
    .frame(width: 720)
    .preferredColorScheme(.dark)
  }
}

private struct SettingsSheet: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        Text("Theme Studio 设置")
          .font(.title2.bold())
        Spacer()
        Button("完成") { dismiss() }
      }

      GroupBox("启动与守护") {
        Toggle("登录时启动 Theme Studio", isOn: Binding(
          get: { model.loginEnabled },
          set: { model.updateLoginItem($0) }
        ))
        .toggleStyle(.switch)
        .padding(.vertical, 7)
      }

      GroupBox("GitHub 社区源") {
        VStack(alignment: .leading, spacing: 8) {
          TextField("https://raw.githubusercontent.com/983033995/Codex-Theme-Gallery/main/registry/registry-v1.json", text: $model.registryURL)
            .textFieldStyle(.roundedBorder)
          Text("只接受 HTTPS JSON 索引；主题和宠物安装时会校验 SHA-256 与文件大小。")
            .font(.caption)
            .foregroundStyle(.secondary)
          Button("立即刷新") { model.refreshCommunity() }
            .disabled(model.registryURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.vertical, 7)
      }

      HStack {
        Button("打开数据目录") { model.openStateFolder() }
        Spacer()
        Button("退出应用", role: .destructive) { model.quit() }
      }
    }
    .padding(22)
    .frame(width: 520)
    .preferredColorScheme(.dark)
  }
}
