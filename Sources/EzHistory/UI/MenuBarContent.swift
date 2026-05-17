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

            if let update = appState.availableUpdate {
                Divider()
                Button {
                    appState.performUpdate()
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Update to v\(update.version)")
                    }
                }
                .disabled(appState.isUpdating)
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

            Text("v\(AppVersion.current)")
                .font(.caption2)
                .foregroundColor(.secondary)

            Button("Quit EzHistory") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(4)
    }
}
