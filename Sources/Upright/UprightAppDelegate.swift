import AppKit
import SwiftUI

/// Owns monitoring for the lifetime of the menu-bar app, independent of windows.
final class UprightAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let monitor = Monitor()
    private var statusItem: NSStatusItem!
    private var window: NSWindow?
    private let statusLine = NSMenuItem(title: "Starting camera…", action: nil, keyEquivalent: "")
    private let calibrationItem = NSMenuItem(title: "Calibrate posture", action: #selector(calibrate), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "figure.seated.side", accessibilityDescription: "Upright posture monitor")
        statusItem.button?.toolTip = "Upright"
        let menu = NSMenu()
        menu.delegate = self
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        let open = NSMenuItem(title: "Open Upright", action: #selector(openWindow), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        calibrationItem.target = self
        menu.addItem(calibrationItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Upright", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
        monitor.start()
    }

    func menuWillOpen(_ menu: NSMenu) {
        statusLine.title = monitor.status
        calibrationItem.title = monitor.isCalibrated ? "Recalibrate posture" : "Calibrate posture"
    }

    @objc private func openWindow() {
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

    @objc private func calibrate() { monitor.calibrate() }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
