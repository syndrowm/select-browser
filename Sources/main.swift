import AppKit

// Manual app bootstrap so we control the activation policy and can reliably
// register the Apple Event handler before LaunchServices delivers the URL.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
