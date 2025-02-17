import Cocoa

// Global variables to retain instances
var statusController: StatusBarController?
var monitor: CoreMonitor?

if #available(macOS 12.0, *) {
    print("Starting CoreGuard...")
    
    autoreleasepool {
        let app = NSApplication.shared
        
        // Basic app setup
        app.setActivationPolicy(.accessory)
        
        // Create and set up status bar
        print("Initializing UI components...")
        statusController = StatusBarController()
        
        // Create and set up monitor with reduced update frequency
        print("Initializing monitoring system...")
        monitor = CoreMonitor.shared
        
        // Run event loop with improved timing
        print("Starting event loop...")
        while true {
            autoreleasepool {
                // Process events with a longer timeout
                if let event = app.nextEvent(matching: .any,
                                           until: Date(timeIntervalSinceNow: 2.0),
                                           inMode: .default,
                                           dequeue: true) {
                    app.sendEvent(event)
                }
                
                // Give more time for event processing
                RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.5))
            }
        }
    }
} else {
    print("CoreGuard requires macOS 12.0 or later")
    exit(1)
}
