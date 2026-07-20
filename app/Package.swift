// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "CodexThemeStudioApp",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "CodexThemeStudio", targets: ["CodexThemeStudioApp"])
  ],
  targets: [
    .executableTarget(
      name: "CodexThemeStudioApp",
      path: "Sources/CodexThemeStudioApp"
    ),
    .testTarget(
      name: "CodexThemeStudioAppTests",
      dependencies: ["CodexThemeStudioApp"],
      path: "Tests/CodexThemeStudioAppTests"
    )
  ],
  swiftLanguageModes: [.v5]
)
