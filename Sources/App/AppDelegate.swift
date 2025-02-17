import Cocoa

@available(macOS 12.0, *)
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var monitor: CoreMonitor?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Application launching...")
        
        // Ensure we're a background application
        NSApp.setActivationPolicy(.accessory)
        
        // Set default threshold
        if UserDefaults.standard.double(forKey: "cpuThreshold") == 0 {
            UserDefaults.standard.set(75.0, forKey: "cpuThreshold")
        }
        
        print("Creating status bar controller...")
        statusBarController = StatusBarController()
        
        print("Initializing monitor...")
        monitor = CoreMonitor.shared
        
        print("Application setup complete")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("Application terminating...")
    }
}
