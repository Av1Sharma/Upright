import AppKit
import SwiftUI

/// Owns monitoring for the lifetime of the menu-bar app, independent of windows.
final class UprightAppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = Monitor()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "figure.seated.side", accessibilityDescription: "Upright posture monitor")
        statusItem.button?.toolTip = "Upright"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 430)
        popover.contentViewController = NSHostingController(rootView: MenuBarView(
            monitor: monitor,
            openDetails: { [weak self] in self?.openWindow() },
            quit: { NSApp.terminate(nil) }
        ))
        monitor.start()
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func openWindow() {
        popover.performClose(nil)
        if window == nil {
            let controller = NSHostingController(rootView: ContentView(monitor: monitor))
            let newWindow = NSWindow(contentViewController: controller)
            newWindow.title = "Upright"
            newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            newWindow.isReleasedWhenClosed = false
            newWindow.setContentSize(NSSize(width: 660, height: 780))
            newWindow.minSize = NSSize(width: 420, height: 520)
            newWindow.center()
            window = newWindow
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
