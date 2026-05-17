import SwiftUI

struct MenuBarContent: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button("Search History  ⌘⇧H") {
                SearchWindowController.shared.show()
            }

            Divider()

            if appState.isIndexing {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Indexing... \(Int(appState.indexingProgress * 100))%")
                        .font(.caption)
                }
            } else {
                Text("\(appState.profileCount) profiles indexed")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(appState.itemCount) items")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let lastDate = appState.lastIndexDate {
                    Text("Last: \(lastDate.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            Button("Reindex Now") {
                Task { await appState.reindex() }
            }
            .disabled(appState.isIndexing)

            Button("Settings...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .keyboardShortcut(",")

            Divider()

            Button("Quit EzHistory") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(4)
    }
}
