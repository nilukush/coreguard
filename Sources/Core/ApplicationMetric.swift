import Foundation
import Combine
import AppKit

struct ApplicationMetric {
    let applicationName: String
    let cpuUsage: Double
}

protocol ApplicationDetector {
    var runningApplications: AnyPublisher<[String], Never> { get }
}

protocol PerformanceMetrics {
    func cpuUsage(for apps: [String]) -> AnyPublisher<[ApplicationMetric], Never>
}

protocol NotificationSystem {
    func sendNotification(title: String, body: String)
}

class NSAppEventDetector: ApplicationDetector {
    private var lastUpdate = Date()
    private var lastNotifiedApps: Set<String> = []
    
    var runningApplications: AnyPublisher<[String], Never> {
        print("Setting up application monitoring...")
        return Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .map { [weak self] _ in
                guard let self = self else { return [] }
                
                // Only update if enough time has passed
                let now = Date()
                if now.timeIntervalSince(self.lastUpdate) < 2.0 {
                    return Array(self.lastNotifiedApps)
                }
                
                self.lastUpdate = now
                
                let apps = NSWorkspace.shared.runningApplications
                    .filter { $0.activationPolicy == .regular }
                    .compactMap { $0.localizedName }
                
                // Only print if apps list has changed
                let newApps = Set(apps)
                if newApps != self.lastNotifiedApps {
                    print("Found \(apps.count) running applications")
                    self.lastNotifiedApps = newApps
                }
                
                return apps
            }
            .eraseToAnyPublisher()
    }
}

class CorePerformanceCollector: PerformanceMetrics {
    func cpuUsage(for apps: [String]) -> AnyPublisher<[ApplicationMetric], Never> {
        // In a real implementation, this would use CorePerformance APIs
        // For now, return mock data
        Just(apps.map { app in
            ApplicationMetric(
                applicationName: app,
                cpuUsage: Double.random(in: 0...100)
            )
        })
        .eraseToAnyPublisher()
    }
}

// Development mode notification handler that doesn't require system permissions
class DevelopmentNotificationHandler: NotificationSystem {
    private var statusItem: NSStatusItem?
    private var lastNotification: String = "No notifications"
    
    init(statusItem: NSStatusItem? = nil) {
        print("Creating DevelopmentNotificationHandler...")
        self.statusItem = statusItem
    }
    
    func sendNotification(title: String, body: String) {
        print("🔔 Notification:")
        print("   Title: \(title)")
        print("   Body: \(body)")
        
        lastNotification = "\(title): \(body)"
        
        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Flash menu bar icon
            if let button = self.statusItem?.button {
                let originalTitle = button.title
                button.title = "⚠️"
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    button.title = originalTitle
                }
            }
            
            // Update menu if available
            if let menu = self.statusItem?.menu {
                // Remove existing notification items
                while menu.items.first?.title.hasPrefix("🔔") ?? false {
                    menu.removeItem(at: 0)
                }
                
                // Add new notification at top
                let item = NSMenuItem(title: "🔔 \(self.lastNotification)", action: nil, keyEquivalent: "")
                menu.insertItem(item, at: 0)
                menu.insertItem(NSMenuItem.separator(), at: 1)
            }
        }
    }
}
