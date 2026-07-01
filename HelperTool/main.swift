import Foundation

// Helper Tool entry point - runs as a privileged XPC service
// Installed via SMJobBless and communicates with the main app via NSXPCConnection

let delegate = HelperToolDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
