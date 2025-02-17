import XCTest
import Combine
@testable import CoreGuard

@available(macOS 12.0, *)
final class CoreMonitorTests: XCTestCase {
    fileprivate var monitor: CoreMonitor!
    fileprivate var mockDetector: MockApplicationDetector!
    fileprivate var mockMetrics: MockPerformanceMetrics!
    fileprivate var mockNotifier: MockNotificationSystem!
    
    override func setUp() {
        super.setUp()
        mockDetector = MockApplicationDetector()
        mockMetrics = MockPerformanceMetrics()
        mockNotifier = MockNotificationSystem()
        monitor = CoreMonitor(appDetector: mockDetector,
                             metricsCollector: mockMetrics,
                             notificationHandler: mockNotifier)
    }
    
    func testThresholdDetection() {
        // Given
        let testApps = ["Safari", "Xcode"]
        UserDefaults.standard.set(75.0, forKey: "cpuThreshold")
        
        // Setup mock responses
        mockDetector.appsSubject.send(testApps)
        mockMetrics.cpuUsageResult = [
            ApplicationMetric(applicationName: "Safari", cpuUsage: 82.0),
            ApplicationMetric(applicationName: "Xcode", cpuUsage: 68.0)
        ]
        
        // When
        let expectation = XCTestExpectation(description: "Threshold check")
        monitor.$highUsageApps
            .dropFirst()
            .sink { metrics in
                expectation.fulfill()
            }
            .store(in: &mockMetrics.cancellables)
        
        // Then
        wait(for: [expectation], timeout: 2)
        XCTAssertEqual(monitor.highUsageApps.count, 1)
        XCTAssertEqual(monitor.highUsageApps["Safari"], 82.0)
        XCTAssertEqual(mockNotifier.notificationCount, 1)
    }
    
    func testNoNotificationBelowThreshold() {
        // Given
        UserDefaults.standard.set(90.0, forKey: "cpuThreshold")
        mockDetector.appsSubject.send(["Notes"])
        mockMetrics.cpuUsageResult = [
            ApplicationMetric(applicationName: "Notes", cpuUsage: 85.0)
        ]
        
        // When
        let expectation = XCTestExpectation(description: "No notification")
        monitor.$highUsageApps
            .dropFirst()
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &mockMetrics.cancellables)
        
        // Then
        wait(for: [expectation], timeout: 2)
        XCTAssertTrue(monitor.highUsageApps.isEmpty)
        XCTAssertEqual(mockNotifier.notificationCount, 0)
    }
}

// MARK: - Mock Implementations
fileprivate class MockApplicationDetector: ApplicationDetector {
    let appsSubject = PassthroughSubject<[String], Never>()
    var runningApplications: AnyPublisher<[String], Never> {
        appsSubject.eraseToAnyPublisher()
    }
}

fileprivate class MockPerformanceMetrics: PerformanceMetrics {
    var cpuUsageResult: [ApplicationMetric] = []
    var cancellables = Set<AnyCancellable>()
    
    func cpuUsage(for apps: [String]) -> AnyPublisher<[ApplicationMetric], Never> {
        Just(cpuUsageResult).eraseToAnyPublisher()
    }
}

fileprivate class MockNotificationSystem: NotificationSystem {
    private(set) var notificationCount = 0
    
    func sendNotification(title: String, body: String) {
        notificationCount += 1
    }
}
