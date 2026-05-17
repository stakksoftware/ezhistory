import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleSearch = Self("toggleSearch", default: .init(.h, modifiers: [.command, .shift]))
}

@main
struct EzHistoryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
                .environmentObject(appState)
        } label: {
            Image(systemName: "clock.arrow.circlepath")
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        KeyboardShortcuts.onKeyUp(for: .toggleSearch) {
            SearchWindowController.shared.toggle()
        }

        Task {
            await AppState.shared.performInitialIndex()
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var indexingProgress: Double = 0
    @Published var isIndexing = false
    @Published var profileCount = 0
    @Published var itemCount = 0
    @Published var lastIndexDate: Date?
    @Published var availableUpdate: UpdateInfo?
    @Published var isUpdating = false

    let indexStore: IndexStore
    let coordinator: IndexCoordinator

    private init() {
        indexStore = IndexStore()
        coordinator = IndexCoordinator(store: indexStore)
    }

    func performInitialIndex() async {
        isIndexing = true
        indexingProgress = 0

        await coordinator.runFullIndex { [weak self] progress in
            Task { @MainActor in
                self?.indexingProgress = progress
            }
        }

        profileCount = (try? indexStore.profileCount()) ?? 0
        itemCount = (try? indexStore.itemCount()) ?? 0
        lastIndexDate = Date()
        isIndexing = false

        coordinator.startScheduledIndexing()

        Task {
            await checkForUpdates()
        }
    }

    func reindex() async {
        isIndexing = true
        await coordinator.runFullIndex(progress: nil)
        profileCount = (try? indexStore.profileCount()) ?? 0
        itemCount = (try? indexStore.itemCount()) ?? 0
        lastIndexDate = Date()
        isIndexing = false
    }

    func checkForUpdates() async {
        if let update = await UpdateChecker.checkForUpdate() {
            availableUpdate = update
        }
    }

    func performUpdate() {
        guard let update = availableUpdate else { return }
        isUpdating = true
        Task {
            let success = await UpdateChecker.performUpdate(from: update.downloadURL)
            if !success {
                isUpdating = false
            }
        }
    }

    func dismissUpdate() {
        availableUpdate = nil
    }
}
