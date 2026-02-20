import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
NSLog("[main] delegate set, calling app.run()")
app.run()
