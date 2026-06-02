import AppKit
import CoreServices

struct Profile: Identifiable, Hashable {
    let directory: String   // on-disk dir name, e.g. "Default", "Profile 1"
    let name: String        // user-facing name, e.g. "Work"
    var id: String { directory }
}

struct Browser: Identifiable {
    let name: String
    let bundleID: String
    let bundleURL: URL
    let executableURL: URL
    let supportDir: String?  // path under ~/Library/Application Support; nil = no profile support
    var profiles: [Profile] = []

    var id: String { bundleID }
    var supportsProfiles: Bool { supportDir != nil && profiles.count > 1 }
    var icon: NSImage { NSWorkspace.shared.icon(forFile: bundleURL.path) }
}

enum BrowserCatalog {
    // name, bundle id, Application Support subdirectory (nil for no profiles)
    private static let known: [(name: String, bundleID: String, supportDir: String?)] = [
        ("Google Chrome", "com.google.Chrome", "Google/Chrome"),
        ("Brave Browser", "com.brave.Browser", "BraveSoftware/Brave-Browser"),
        ("Safari", "com.apple.Safari", nil),
    ]

    static func installed() -> [Browser] {
        let ws = NSWorkspace.shared
        var browsers: [Browser] = []
        for entry in known {
            guard let bundleURL = ws.urlForApplication(withBundleIdentifier: entry.bundleID),
                  let bundle = Bundle(url: bundleURL),
                  let exec = bundle.executableURL else { continue }
            var browser = Browser(
                name: entry.name,
                bundleID: entry.bundleID,
                bundleURL: bundleURL,
                executableURL: exec,
                supportDir: entry.supportDir
            )
            if let dir = entry.supportDir {
                browser.profiles = loadChromiumProfiles(supportDir: dir)
            }
            browsers.append(browser)
        }
        return browsers
    }

    /// Reads profile directories + display names from a Chromium "Local State" file.
    private static func loadChromiumProfiles(supportDir: String) -> [Profile] {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")
            .appendingPathComponent(supportDir)
        let localState = base.appendingPathComponent("Local State")

        guard let data = try? Data(contentsOf: localState),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profileSection = json["profile"] as? [String: Any],
              let cache = profileSection["info_cache"] as? [String: Any] else {
            // Fall back to the always-present Default profile.
            return [Profile(directory: "Default", name: "Default")]
        }

        var profiles: [Profile] = []
        for (dir, value) in cache {
            let info = value as? [String: Any]
            let name = (info?["name"] as? String) ?? dir
            profiles.append(Profile(directory: dir, name: name))
        }

        profiles.sort { a, b in
            if a.directory == "Default" { return true }
            if b.directory == "Default" { return false }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        return profiles.isEmpty ? [Profile(directory: "Default", name: "Default")] : profiles
    }
}

enum Launcher {
    static func open(url: URL, browser: Browser, profile: Profile?) {
        if let profile {
            // Run the browser binary directly so --profile-directory is honored
            // even when the browser is already running (Chromium routes the URL
            // to the existing instance / requested profile).
            let process = Process()
            process.executableURL = browser.executableURL
            process.arguments = ["--profile-directory=\(profile.directory)", url.absoluteString]
            try? process.run()
        } else {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([url], withApplicationAt: browser.bundleURL,
                                    configuration: config, completionHandler: nil)
        }
    }

    static func setAsDefaultBrowser(completion: @escaping (Bool) -> Void) {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            completion(false)
            return
        }
        // This may trigger a system confirmation prompt; the immediate return
        // code is unreliable (often permErr while the prompt is pending), so we
        // verify the actual handler afterwards instead of trusting it.
        LSSetDefaultHandlerForURLScheme("https" as CFString, bundleID as CFString)
        LSSetDefaultHandlerForURLScheme("http" as CFString, bundleID as CFString)
        verifyDefault(attemptsLeft: 16, completion: completion) // poll up to ~8s
    }

    static func isDefaultBrowser() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let current = LSCopyDefaultHandlerForURLScheme("http" as CFString)?
                  .takeRetainedValue() as String? else { return false }
        return current.caseInsensitiveCompare(bundleID) == .orderedSame
    }

    private static func verifyDefault(attemptsLeft: Int, completion: @escaping (Bool) -> Void) {
        if isDefaultBrowser() {
            completion(true)
        } else if attemptsLeft <= 0 {
            completion(false)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                verifyDefault(attemptsLeft: attemptsLeft - 1, completion: completion)
            }
        }
    }
}
