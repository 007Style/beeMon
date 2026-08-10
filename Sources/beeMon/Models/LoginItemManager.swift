import Foundation
import ServiceManagement

// MARK: - Login Item Manager
// Uses SMAppService (macOS 13+) to register/unregister beeMon as a login item.

@MainActor
final class LoginItemManager {
    static let shared = LoginItemManager()
    private init() {}

    var isEnabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Silently ignore — user may have denied in System Settings
            print("LoginItemManager: \(enabled ? "register" : "unregister") failed: \(error)")
        }
    }

    func toggle() {
        setEnabled(!isEnabled)
    }
}
