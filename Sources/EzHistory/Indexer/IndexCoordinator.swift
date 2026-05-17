import Foundation

final class IndexCoordinator: @unchecked Sendable {
    let store: IndexStore
    private var timer: Timer?
    private var fsEventStream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "com.ezhistory.coordinator")

    init(store: IndexStore) {
        self.store = store
    }

    func runFullIndex(progress: ((Double) -> Void)?) async {
        let scanner = ChromeProfileScanner()
        let profiles = scanner.scan()

        let total = Double(profiles.count)
        guard total > 0 else { return }

        for (index, profile) in profiles.enumerated() {
            do {
                let profileId = try store.upsertProfile(profile)

                let historyImporter = HistoryImporter(store: store)
                try historyImporter.importHistory(profile: profile, profileId: profileId)
                try historyImporter.importDownloads(profile: profile, profileId: profileId)

                let bookmarksImporter = BookmarksImporter(store: store)
                try bookmarksImporter.importBookmarks(profile: profile, profileId: profileId)

                let loginsImporter = LoginsImporter(store: store)
                try loginsImporter.importLogins(profile: profile, profileId: profileId)

                let autofillImporter = AutofillImporter(store: store)
                try autofillImporter.importAutofill(profile: profile, profileId: profileId)

            } catch {
                print("Error indexing profile \(profile.dirName): \(error)")
            }

            progress?((Double(index + 1)) / total)
        }
    }

    func startScheduledIndexing() {
        let intervalMinutes = UserDefaults.standard.integer(forKey: "refreshIntervalMinutes")
        let interval = TimeInterval(max(intervalMinutes, 5) * 60)

        DispatchQueue.main.async { [weak self] in
            self?.setupTimer(interval: interval)
            self?.setupFSEvents()
        }
    }

    private func setupTimer(interval: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task {
                await self.runFullIndex(progress: nil)
            }
        }
    }

    private func setupFSEvents() {
        let chromePath = ChromeProfileScanner.chromeBasePath.path as CFString
        let pathsToWatch = [chromePath] as CFArray

        let unmanaged = Unmanaged.passRetained(self)
        var context = FSEventStreamContext(
            version: 0,
            info: unmanaged.toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        guard let stream = FSEventStreamCreate(
            nil,
            { (_, info, _, _, _, _) in
                guard let info = info else { return }
                let coordinator = Unmanaged<IndexCoordinator>.fromOpaque(info).takeUnretainedValue()
                Task {
                    await coordinator.runFullIndex(progress: nil)
                }
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            5.0,
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer)
        ) else {
            unmanaged.release()
            return
        }

        let dispatchQueue = DispatchQueue(label: "com.ezhistory.fsevents")
        FSEventStreamSetDispatchQueue(stream, dispatchQueue)
        FSEventStreamStart(stream)
        fsEventStream = stream
    }
}
