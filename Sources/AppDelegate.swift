import Cocoa
import SwiftUI

// MARK: - App Delegate
//
// Manages the menu bar item, overlay windows, and the z-ordering
// engine that keeps the blur behind the active application.

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: Core State

    let state = AppState()

    // MARK: UI References

    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var overlayWindows: [NSWindow] = []
    private var timer: Timer?

    // MARK: Z-Order Tracking

    private var lastFrontPID: Int32 = -1

    // MARK: Mouse-Shake Detection

    private var mouseHistory: [(pos: CGPoint, time: TimeInterval)] = []
    private var lastShakeTime = Date()
    private var wasEnabled = false

    // MARK: Keyboard Shortcuts

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        state.onUpdateOverlays = { [weak self] in self?.refreshOverlays() }

        timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            self?.updateOverlayZOrder()
        }

        // Mouse-shake monitors
        NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved(event: event)
        }
        NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved(event: event)
            return event
        }

        setupKeyboardShortcuts()

        showSettings()
    }

    private func setupKeyboardShortcuts() {
        let keyDownHandler: (NSEvent) -> Void = { [weak self] event in
            // KeyCode 126 is Up Arrow. Check for Command and Shift.
            if event.keyCode == 126 && event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) {
                DispatchQueue.main.async { self?.showSettings() }
            }
        }
        
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: keyDownHandler)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            keyDownHandler(event)
            return event
        }
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "tsuki"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Control Centre…",
            action: #selector(showSettings),
            keyEquivalent: ","
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem.menu = menu
    }

    // MARK: - Settings Window

    @objc func showSettings() {
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView(state: state))
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 340, height: 500),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title                     = "tsuki Aesthetic Centre"
            window.isReleasedWhenClosed       = false
            window.titlebarAppearsTransparent = true
            window.contentViewController      = host
            window.center()
            window.level = .floating
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Overlay Window Management

    private func recreateOverlayWindows() {
        overlayWindows.forEach { $0.close() }
        overlayWindows.removeAll()

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.level              = .normal
            window.backgroundColor    = .clear
            window.isOpaque           = false
            window.hasShadow          = false
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

            let overlay = OverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
            overlay.applySettings(state: state)
            // Start invisible for gradual fade-in
            overlay.layer?.opacity = 0
            window.contentView = overlay
            overlayWindows.append(window)
        }
    }

    /// Fade all overlays to target opacity.
    private func fadeOverlays(to opacity: Float, duration: CFTimeInterval = 0.4) {
        for window in overlayWindows {
            if let overlay = window.contentView as? OverlayView {
                overlay.animateOpacity(to: opacity, duration: duration)
            }
        }
    }

    private func refreshOverlays() {
        for window in overlayWindows {
            if let overlay = window.contentView as? OverlayView {
                overlay.applySettings(state: state)
            }
        }
        lastFrontPID = -1
        updateOverlayZOrder()
    }

    // MARK: - Z-Order Engine
    //
    // Instead of cutting holes in the overlay (which always leaves visible
    // gaps around window edges), we position the blur overlay at `.normal`
    // window level and slip it directly *behind* the frontmost application
    // window.  The active window sits naturally on top with its real shadow
    // and rounded corners — zero masking artefacts.

    private func updateOverlayZOrder() {
        guard state.isEnabled else {
            if wasEnabled {
                fadeOverlays(to: 0, duration: 0.3)
                // Delay orderOut so the fade animation plays
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                    guard let self = self, !self.state.isEnabled else { return }
                    self.overlayWindows.forEach { $0.orderOut(nil) }
                }
                wasEnabled = false
            }
            return
        }

        if overlayWindows.count != NSScreen.screens.count {
            recreateOverlayWindows()
        }

        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let frontPID = frontApp.processIdentifier
        let myPID    = NSRunningApplication.current.processIdentifier

        // Don't re-order while our own settings panel is focused.
        guard frontPID != myPID else { return }

        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return }

        // CGWindowList returns windows in front-to-back z-order.
        // Find the topmost layer-0 window owned by the front app.
        for info in windowList {
            guard let layer    = info[kCGWindowLayer as String]    as? Int,   layer == 0 else { continue }
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int32, ownerPID == frontPID else { continue }
            guard let windowID = info[kCGWindowNumber as String]   as? Int else { continue }

            for w in overlayWindows {
                if !w.isVisible { w.orderBack(nil) }
                w.order(.below, relativeTo: windowID)
            }
            // Gradual fade-in if just enabled or first appearance
            if !wasEnabled {
                fadeOverlays(to: 1.0, duration: 0.5)
                wasEnabled = true
            }
            lastFrontPID = frontPID
            return
        }

        // Fallback: no front window found (e.g. desktop is focused).
        for w in overlayWindows where !w.isVisible {
            w.orderBack(nil)
        }
    }

    // MARK: - Mouse-Shake Toggle
    //
    // Detects a rapid horizontal shake gesture (≥3 direction reversals
    // within 400 ms covering ≥600 pt) and toggles focus mode.

    private func handleMouseMoved(event: NSEvent) {
        let pos = NSEvent.mouseLocation
        let now = Date().timeIntervalSince1970

        mouseHistory.append((pos: pos, time: now))
        mouseHistory.removeAll { now - $0.time > 0.4 }

        guard mouseHistory.count >= 4 else { return }

        var xReversals = 0
        var lastDx: CGFloat = 0
        var totalDist: CGFloat = 0

        for i in 1..<mouseHistory.count {
            let dx = mouseHistory[i].pos.x - mouseHistory[i - 1].pos.x
            totalDist += hypot(dx, mouseHistory[i].pos.y - mouseHistory[i - 1].pos.y)
            if abs(dx) > 3 {
                if (dx > 0 && lastDx < 0) || (dx < 0 && lastDx > 0) { xReversals += 1 }
                lastDx = dx
            }
        }

        if xReversals >= 3 && totalDist > 600 {
            if Date().timeIntervalSince(lastShakeTime) > 1.0 {
                state.isEnabled.toggle()
                lastShakeTime = Date()
                mouseHistory.removeAll()
            }
        }
    }
}
