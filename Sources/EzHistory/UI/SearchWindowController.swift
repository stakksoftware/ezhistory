import AppKit
import SwiftUI

@MainActor
final class SearchWindowController {
    static let shared = SearchWindowController()

    private var window: NSWindow?
    private var hostingView: NSHostingView<AnyView>?

    func toggle() {
        if let window = window, window.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        if window == nil {
            createWindow()
        }

        guard let window = window else { return }

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowWidth: CGFloat = 700
            let windowHeight: CGFloat = 500
            let x = screenFrame.midX - windowWidth / 2
            let y = screenFrame.maxY - windowHeight - 100
            window.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func createWindow() {
        let contentView = SearchWindow(onDismiss: { [weak self] in
            self?.hide()
        })

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.animationBehavior = .utilityWindow
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hostingView = NSHostingView(rootView: AnyView(
            contentView.environmentObject(AppState.shared)
        ))
        window.contentView = hostingView

        self.window = window
        self.hostingView = hostingView
    }
}
