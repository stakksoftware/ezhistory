import SwiftUI
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [SearchResult] = []
    @Published var detailResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var selectedId: Int64?
    @Published var selectedKinds: Set<String> = []
    @Published var selectedProfileIds: Set<Int64> = []
    @Published var selectedBrowsers: Set<String> = []
    @Published var timeFilter: TimeFilter = .all

    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    var selectedResult: SearchResult? {
        results.first { $0.id == selectedId }
    }

    enum TimeFilter: String, CaseIterable, Identifiable {
        case all = "All time"
        case today = "Today"
        case week = "7 days"
        case month = "30 days"
        case year = "1 year"

        var id: String { rawValue }

        var date: Date? {
            switch self {
            case .all: return nil
            case .today: return Calendar.current.startOfDay(for: Date())
            case .week: return Calendar.current.date(byAdding: .day, value: -7, to: Date())
            case .month: return Calendar.current.date(byAdding: .day, value: -30, to: Date())
            case .year: return Calendar.current.date(byAdding: .year, value: -1, to: Date())
            }
        }
    }

    init() {
        $query
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] newQuery in
                self?.performSearch(newQuery)
            }
            .store(in: &cancellables)

        $selectedId
            .compactMap { $0 }
            .sink { [weak self] _ in
                self?.loadDetail()
            }
            .store(in: &cancellables)

        Publishers.MergeMany(
            $selectedKinds.map { _ in () }.eraseToAnyPublisher(),
            $selectedProfileIds.map { _ in () }.eraseToAnyPublisher(),
            $selectedBrowsers.map { _ in () }.eraseToAnyPublisher(),
            $timeFilter.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
        .sink { [weak self] in
            guard let self = self, !self.query.isEmpty else { return }
            self.performSearch(self.query)
        }
        .store(in: &cancellables)
    }

    func performSearch(_ query: String) {
        searchTask?.cancel()

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            results = []
            detailResults = []
            selectedId = nil
            return
        }

        isSearching = true

        searchTask = Task {
            do {
                let found = try AppState.shared.indexStore.search(
                    query: query,
                    kinds: selectedKinds.isEmpty ? nil : selectedKinds,
                    profileIds: selectedProfileIds.isEmpty ? nil : selectedProfileIds,
                    browsers: selectedBrowsers.isEmpty ? nil : selectedBrowsers,
                    since: timeFilter.date
                )

                guard !Task.isCancelled else { return }

                results = found
                if let first = found.first {
                    selectedId = first.id
                }
            } catch {
                print("Search error: \(error)")
            }

            isSearching = false
        }
    }

    private func loadDetail() {
        guard let result = selectedResult else {
            detailResults = []
            return
        }

        Task {
            do {
                detailResults = try AppState.shared.indexStore.profilesForURL(result.url)
            } catch {
                detailResults = []
            }
        }
    }

    func openSelected() {
        guard let result = selectedResult else { return }
        ChromeLauncher.openURL(result.url, inProfile: result.dirName, browser: result.browser)
    }

    func moveSelection(down: Bool) {
        guard !results.isEmpty else { return }
        if let currentId = selectedId,
           let currentIndex = results.firstIndex(where: { $0.id == currentId }) {
            let nextIndex = down
                ? min(currentIndex + 1, results.count - 1)
                : max(currentIndex - 1, 0)
            selectedId = results[nextIndex].id
        } else {
            selectedId = results.first?.id
        }
    }
}
