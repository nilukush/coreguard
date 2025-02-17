import Cocoa
import Combine

class StatusBarController {
    private var statusItem: NSStatusItem
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        print("Initializing StatusBarController...")
        
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Create menu
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        // Set up initial menu items
        menu.addItem(withTitle: "CPU Threshold", action: nil, keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "High Usage Apps", action: nil, keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        // Set menu and button title
        statusItem.menu = menu
        statusItem.button?.title = "CPU"
        
        print("Menu setup complete")
        
        // Initialize notification handler
        print("Initializing notification handler...")
        let notificationHandler = DevelopmentNotificationHandler(statusItem: statusItem)
        _ = CoreMonitor.shared.updateNotificationHandler(notificationHandler)
        print("Notification handler initialized")
        
        // Subscribe to CPU updates
        CoreMonitor.shared.$highUsageApps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] apps in
                self?.updateMenu(with: apps)
            }
            .store(in: &cancellables)
    }
    
    private func updateMenu(with apps: [String: Double]) {
        guard let menu = statusItem.menu else { return }
        
        // Update threshold item
        if let thresholdItem = menu.item(at: 0) {
            let threshold = UserDefaults.standard.double(forKey: "cpuThreshold")
            thresholdItem.title = "CPU Threshold: \(Int(threshold))%"
        }
        
        // Find the "High Usage Apps" section
        if let headerIndex = menu.items.firstIndex(where: { $0.title == "High Usage Apps" }) {
            // Remove old items
            while headerIndex + 1 < menu.items.count && !menu.items[headerIndex + 1].isSeparatorItem {
                menu.removeItem(at: headerIndex + 1)
            }
            
            // Add new items
            for (app, usage) in apps.sorted(by: { $0.value > $1.value }) {
                let item = NSMenuItem(
                    title: "\(app): \(Int(usage))% CPU",
                    action: nil,
                    keyEquivalent: ""
                )
                menu.insertItem(item, at: headerIndex + 1)
            }
        }
    }
}
