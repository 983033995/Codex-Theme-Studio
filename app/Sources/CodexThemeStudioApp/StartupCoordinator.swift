import AppKit

struct RunningManagerInstance: Equatable {
  let processIdentifier: pid_t
  let launchDate: Date
}

enum StartupPolicy {
  static let legacyManagerBundleIdentifier = "com.codexdreamskin.manager"

  static func preferredManager(
    from instances: [RunningManagerInstance]
  ) -> RunningManagerInstance? {
    instances.max { left, right in
      if left.launchDate == right.launchDate {
        return left.processIdentifier < right.processIdentifier
      }
      return left.launchDate < right.launchDate
    }
  }

  static func shouldAutoRepair(
    status: EngineStatus,
    attempted: Bool,
    busy: Bool
  ) -> Bool {
    status.needsRepair && !attempted && !busy
  }
}

@MainActor
struct ManagerInstanceService {
  func becomePrimary() -> Bool {
    guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return true }
    let current = NSRunningApplication.current
    var applications = NSRunningApplication.runningApplications(
      withBundleIdentifier: bundleIdentifier
    )
    if !applications.contains(where: { $0.processIdentifier == current.processIdentifier }) {
      applications.append(current)
    }

    let instances = applications.map {
      RunningManagerInstance(
        processIdentifier: $0.processIdentifier,
        launchDate: $0.launchDate ?? .distantPast
      )
    }
    guard StartupPolicy.preferredManager(from: instances)?.processIdentifier
      == current.processIdentifier else {
      NSApplication.shared.terminate(nil)
      return false
    }

    for application in applications where application.processIdentifier != current.processIdentifier {
      guard application.terminate() else { continue }
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        if !application.isTerminated {
          application.forceTerminate()
        }
      }
    }
    return true
  }
}

@MainActor
struct LegacyManagerService {
  func retireRunningManager() -> Int {
    NSRunningApplication.runningApplications(
      withBundleIdentifier: StartupPolicy.legacyManagerBundleIdentifier
    ).reduce(into: 0) { retired, application in
      if application.terminate() { retired += 1 }
    }
  }
}
