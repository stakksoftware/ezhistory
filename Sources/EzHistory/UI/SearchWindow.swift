import SwiftUI

struct SearchWindow: View {
    let onDismiss: () -> Void

    @StateObject private var viewModel = SearchViewModel()
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if let update = appState.availableUpdate {
                updateBanner(update)
            }

            searchBar
            Divider()

            if viewModel.results.isEmpty && !viewModel.query.isEmpty && !viewModel.isSearching {
                emptyState
            } else if viewModel.query.isEmpty {
                welcomeState
            } else {
                HSplitView {
                    resultsList
                        .frame(minWidth: 350)

                    if viewModel.selectedResult != nil {
                        ResultDetailView(
                            url: viewModel.selectedResult!.url,
                            results: viewModel.detailResults
                        )
                        .frame(minWidth: 250)
                    }
                }
            }
        }
        .frame(minWidth: 700, minHeight: 400)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .onExitCommand { onDismiss() }
    }

    private func updateBanner(_ update: UpdateInfo) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundColor(.white)
            Text("EzHistory v\(update.version) available")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
            Spacer()
            Button {
                appState.performUpdate()
            } label: {
                if appState.isUpdating {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Text("Update Now")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.2))
            .clipShape(Capsule())
            .foregroundColor(.white)
            .disabled(appState.isUpdating)

            Button {
                appState.dismissUpdate()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.accentColor)
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundColor(.secondary)

            TextField("Search history, bookmarks, logins...", text: $viewModel.query)
                .textFieldStyle(.plain)
                .font(.title3)
                .onSubmit {
                    viewModel.openSelected()
                }

            if !viewModel.query.isEmpty {
                Button(action: { viewModel.query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var resultsList: some View {
        VStack(spacing: 0) {
            FilterBar(viewModel: viewModel)
            Divider()

            ScrollViewReader { proxy in
                List(selection: $viewModel.selectedId) {
                    ForEach(viewModel.results) { result in
                        ResultRow(result: result)
                            .tag(result.id)
                            .id(result.id)
                            .contextMenu {
                                Button("Open in \(result.browser) / \(result.displayName)") {
                                    ChromeLauncher.openURL(result.url, inProfile: result.dirName, browser: result.browser)
                                }
                                Button("Copy URL") {
                                    ChromeLauncher.copyURL(result.url)
                                }
                                if result.kind == "download",
                                   let extra = result.extraJson,
                                   let data = extra.data(using: .utf8),
                                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                   let path = json["targetPath"] as? String, !path.isEmpty {
                                    Button("Reveal in Finder") {
                                        ChromeLauncher.revealInFinder(path)
                                    }
                                }
                                Divider()
                                Text("\(result.browser) / \(result.displayName)")
                                if !result.accountEmail.isEmpty {
                                    Text(result.accountEmail)
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .onChange(of: viewModel.selectedId) { newValue in
                    if let id = newValue {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No results found")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("Try a different search term")
                .font(.caption)
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var welcomeState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            Text("EzHistory")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Search across all your browser profiles")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("⌘⇧H to toggle this window")
                .font(.caption)
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                .padding(.top, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
