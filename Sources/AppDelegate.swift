import AppKit
import SwiftUI
import CoreServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var pendingURL: URL?

    // Register for the GURL Apple Event as early as possible. When the app is
    // launched by clicking a link, LaunchServices delivers the URL via this
    // event, and it can arrive before applicationDidFinishLaunching.
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:reply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpMainMenu()
        NSApp.activate(ignoringOtherApps: true)

        // If we were launched directly (no URL), give the Apple Event a moment
        // to arrive; otherwise show the picker in "no URL" mode.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, self.window == nil else { return }
            self.showPicker(for: nil)
        }
    }

    // Quit the app when its window is closed (e.g. after setting the default
    // browser in the manually-launched, no-URL case).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // A minimal menu so standard shortcuts (notably ⌘Q) work.
    private func setUpMainMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu

        let name = ProcessInfo.processInfo.processName
        appMenu.addItem(withTitle: "Hide \(name)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit \(name)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        NSApp.mainMenu = mainMenu
    }

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: string) else { return }
        pendingURL = url
        if window == nil {
            showPicker(for: url)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showPicker(for url: URL?) {
        guard window == nil else { return }

        let browsers = BrowserCatalog.installed()
        let effectiveURL = url ?? pendingURL
        let view = PickerView(
            url: effectiveURL,
            browsers: browsers,
            savedRule: RuleStore.rule(forHost: effectiveURL?.host),
            onOpen: { [weak self] browser, profile in self?.open(browser: browser, profile: profile) },
            onSetDefault: { completion in Launcher.setAsDefaultBrowser(completion: completion) },
            onContentSize: { [weak self] size in self?.resizeWindow(toContent: size) }
        )

        // No constraint-driven auto-sizing: the picker measures itself and we
        // resize the window explicitly (see resizeWindow). Constraint-based
        // auto-sizing re-enters the layout pass and crashes intermittently.
        let hosting = NSHostingController(rootView: view)
        hosting.sizingOptions = []

        let win = NSWindow(contentViewController: hosting)
        win.styleMask = [.titled, .closable]
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.title = "Select Browser"
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false
        win.level = .floating
        win.setContentSize(NSSize(width: 380, height: 320)) // initial; corrected on first measure
        win.center()
        window = win

        // Quit when this window closes — observed via notification so we don't
        // override the hosting controller's own window delegate (which it uses
        // for content auto-sizing).
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: win,
            queue: .main
        ) { _ in NSApp.terminate(nil) }

        win.makeKeyAndOrderFront(nil)
    }

    /// Resize the window to fit measured content, anchored at its top-left.
    /// Deferred to the next runloop tick so it never runs inside the SwiftUI
    /// layout pass (which is what made constraint-based sizing crash).
    private func resizeWindow(toContent size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        DispatchQueue.main.async { [weak self] in
            guard let win = self?.window else { return }
            let target = win.frameRect(forContentRect: NSRect(origin: .zero, size: size)).size
            let current = win.frame.size
            guard abs(current.width - target.width) > 0.5
                || abs(current.height - target.height) > 0.5 else { return }
            let topLeftY = win.frame.maxY
            var frame = win.frame
            frame.size = target
            frame.origin.y = topLeftY - target.height
            win.setFrame(frame, display: true, animate: false)
        }
    }

    private func open(browser: Browser, profile: Profile?) {
        if let url = pendingURL {
            // Remember this choice for the host so it's pre-selected next time.
            RuleStore.save(
                DomainRule(bundleID: browser.bundleID, profileDirectory: profile?.directory),
                forHost: url.host
            )
            Launcher.open(url: url, browser: browser, profile: profile)
        }
        // Give the launch hand-off a beat to complete, then exit.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.terminate(nil)
        }
    }
}
