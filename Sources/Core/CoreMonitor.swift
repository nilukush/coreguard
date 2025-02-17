import Foundation
import Combine
import os.signpost
import Dispatch

// MARK: - Core Monitoring System
/// Handles CPU usage monitoring and threshold detection
/// - Tag: CoreMonitor
@available(macOS 12.0, *)
final class CoreMonitor: NSObject {
    static let shared = CoreMonitor()
    
    // MARK: - Dependencies
    private let appDetector: ApplicationDetector
    private let metricsCollector: PerformanceMetrics
    private var notificationHandler: NotificationSystem
    private let signposter = OSSignposter()
    
    // MARK: - State
    @Published private(set) var highUsageApps: [String: Double] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var lastNotificationTime = Date()
    private var consecutiveNotifications = 0
    
    // MARK: - Configuration
    private let minNotificationInterval: TimeInterval = 5.0
    private let maxConsecutiveNotifications = 3
    
    // MARK: - Notification Handler Management
    func updateNotificationHandler(_ handler: NotificationSystem) -> CoreMonitor {
        self.notificationHandler = handler
        return self
    }
    
    // MARK: - Initialization
    init(appDetector: ApplicationDetector = NSAppEventDetector(),
         metricsCollector: PerformanceMetrics = CorePerformanceCollector(),
         notificationHandler: NotificationSystem = DevelopmentNotificationHandler()) {
        print("Initializing CoreMonitor...")
        self.appDetector = appDetector
        self.metricsCollector = metricsCollector
        self.notificationHandler = notificationHandler
        super.init()
        
        print("Setting up monitoring pipeline...")
        setupMonitoringPipeline()
        print("CoreMonitor initialization complete")
    }
    
    // MARK: - Monitoring Pipeline
    private func setupMonitoringPipeline() {
        let signpostID = signposter.makeSignpostID()
        
        appDetector.runningApplications
            .throttle(for: DispatchQueue.SchedulerTimeType.Stride.seconds(1), 
                     scheduler: DispatchQueue.global(qos: .userInitiated), 
                     latest: true)
            .flatMap { [metricsCollector] (apps: [String]) in
                metricsCollector.cpuUsage(for: apps)
            }
            .handleEvents(receiveOutput: { [weak self] (metrics: [ApplicationMetric]) in
                self?.signposter.emitEvent("MetricsReceived", id: signpostID)
            })
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                self?.processMetrics(metrics)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Threshold Processing
    private func processMetrics(_ metrics: [ApplicationMetric]) {
        let currentThreshold = UserDefaults.standard.double(forKey: "cpuThreshold")
        let filtered = metrics.filter { $0.cpuUsage >= currentThreshold }
        
        // Update high usage apps
        highUsageApps = filtered.reduce(into: [:]) { result, metric in
            result[metric.applicationName] = metric.cpuUsage
        }
        
        // Check if we should send notification
        let now = Date()
        if !filtered.isEmpty && shouldSendNotification(at: now) {
            lastNotificationTime = now
            consecutiveNotifications += 1
            
            // Format notification message
            let highUsageList = filtered
                .sorted { $0.cpuUsage > $1.cpuUsage }
                .prefix(3)
                .map { "\($0.applicationName): \(Int($0.cpuUsage))%" }
                .joined(separator: ", ")
            
            let message = filtered.count > 3 
                ? "\(highUsageList) and \(filtered.count - 3) more"
                : highUsageList
            
            notificationHandler.sendNotification(
                title: "High CPU Usage Detected",
                body: "Apps exceeding \(Int(currentThreshold))% threshold: \(message)"
            )
        } else if filtered.isEmpty {
            // Reset consecutive notifications when no high usage
            consecutiveNotifications = 0
        }
    }
    
    private func shouldSendNotification(at time: Date) -> Bool {
        // Check time interval
        guard time.timeIntervalSince(lastNotificationTime) >= minNotificationInterval else {
            return false
        }
        
        // Check consecutive notifications
        guard consecutiveNotifications < maxConsecutiveNotifications else {
            // Reset counter after a longer pause
            if time.timeIntervalSince(lastNotificationTime) >= minNotificationInterval * 2 {
                consecutiveNotifications = 0
                return true
            }
            return false
        }
        
        return true
    }
}
