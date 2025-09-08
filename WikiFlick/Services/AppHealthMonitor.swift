import Foundation
import UIKit

/// Comprehensive app health monitoring service for detecting runtime issues
final class AppHealthMonitor {
    static let shared = AppHealthMonitor()
    
    private init() {}
    
    // MARK: - Health Check Methods
    
    /// Performs comprehensive app health check
    func performHealthCheck() {
        #if DEBUG
        LoggingService.shared.logInfo("🏥 Starting comprehensive app health check", category: .general)
        
        checkMemoryUsage()
        checkThreadingIssues()
        checkNetworkConfiguration()
        checkCacheHealth()
        checkSecurityConfiguration()
        checkCriticalServices()
        
        LoggingService.shared.logInfo("✅ App health check completed", category: .general)
        #endif
    }
    
    // MARK: - Memory Monitoring
    
    private func checkMemoryUsage() {
        let memoryUsage = getMemoryUsage()
        LoggingService.shared.logMemoryUsage("Total App", bytes: memoryUsage)
        
        if memoryUsage > 100 * 1024 * 1024 { // 100MB
            LoggingService.shared.logWarning("High memory usage detected: \(memoryUsage / 1024 / 1024)MB", category: .general)
        }
    }
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    // MARK: - Threading Checks
    
    private func checkThreadingIssues() {
        // Check if we're on main thread when we shouldn't be
        if Thread.isMainThread {
            LoggingService.shared.logInfo("Health check running on main thread (expected)", category: .general)
        }
        
        // Simulate checking for potential deadlocks or long-running operations
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Test a quick operation
        DispatchQueue.global().sync {
            Thread.sleep(forTimeInterval: 0.001) // 1ms test
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        if duration > 0.1 { // 100ms
            LoggingService.shared.logWarning("Slow threading operation detected: \(duration)s", category: .general)
        }
    }
    
    // MARK: - Network Configuration
    
    private func checkNetworkConfiguration() {
        // Check secure URL builder
        if !SecureURLBuilder.isValidLanguageCode("en") {
            LoggingService.shared.logError("URL builder validation failed for basic language code", category: .security)
        }
        
        // Check certificate pinning configuration
        #if DEBUG
        CertificatePinningService.shared.validateConfiguration()
        #endif
    }
    
    // MARK: - Cache Health
    
    private func checkCacheHealth() {
        let cacheManager = ArticleCacheManager.shared
        let memoryUsage = cacheManager.cacheMemoryUsage()
        
        LoggingService.shared.logMemoryUsage("Cache", bytes: memoryUsage)
        
        // Test cache functionality
        let testArticle = WikipediaArticle(
            title: "Health Check Test",
            extract: "Test article for health monitoring",
            pageId: -999,
            imageURL: nil,
            fullURL: "https://test.example.com"
        )
        
        cacheManager.cacheArticle(testArticle)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let retrieved = cacheManager.getCachedArticle(pageId: -999)
            if retrieved == nil {
                LoggingService.shared.logError("Cache test failed - article not retrieved", category: .cache)
            } else {
                LoggingService.shared.logInfo("Cache test passed", category: .cache)
            }
        }
    }
    
    // MARK: - Security Configuration
    
    private func checkSecurityConfiguration() {
        // Check secure config manager
        let config = SecureConfigManager.shared
        
        if config.interstitialAdUnitID.isEmpty {
            LoggingService.shared.logCritical("Interstitial Ad Unit ID is empty!", category: .security)
        }
        
        if config.nativeAdUnitID.isEmpty {
            LoggingService.shared.logCritical("Native Ad Unit ID is empty!", category: .security)
        }
        
        if config.rewardedAdUnitID.isEmpty {
            LoggingService.shared.logCritical("Rewarded Ad Unit ID is empty!", category: .security)
        }
    }
    
    // MARK: - Critical Services
    
    private func checkCriticalServices() {
        // Check ATT Manager
        let attManager = ATTManager.shared
        LoggingService.shared.logInfo("ATT Status: \(attManager.getCurrentStatus())", category: .general)
        
        // Check Ad Manager
        let adManager = AdMobManager.shared
        if adManager.isCurrentNativeAdValid() {
            LoggingService.shared.logInfo("Native ad loaded and valid", category: .ads)
        } else {
            LoggingService.shared.logWarning("No valid native ad available", category: .ads)
        }
    }
    
    // MARK: - Crash Detection
    
    /// Sets up crash detection and reporting
    func setupCrashDetection() {
        // Set up exception handler
        NSSetUncaughtExceptionHandler { exception in
            LoggingService.shared.logCritical("Uncaught exception: \(exception)", category: .security)
            LoggingService.shared.logCritical("Stack trace: \(exception.callStackSymbols)", category: .security)
        }
        
        // Set up signal handler for crashes
        signal(SIGABRT) { signal in
            LoggingService.shared.logCritical("App crashed with SIGABRT", category: .security)
        }
        
        signal(SIGILL) { signal in
            LoggingService.shared.logCritical("App crashed with SIGILL", category: .security)
        }
        
        signal(SIGSEGV) { signal in
            LoggingService.shared.logCritical("App crashed with SIGSEGV", category: .security)
        }
        
        signal(SIGFPE) { signal in
            LoggingService.shared.logCritical("App crashed with SIGFPE", category: .security)
        }
        
        signal(SIGBUS) { signal in
            LoggingService.shared.logCritical("App crashed with SIGBUS", category: .security)
        }
    }
    
    // MARK: - Performance Monitoring
    
    /// Starts performance monitoring
    func startPerformanceMonitoring() {
        #if DEBUG
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            self.checkMemoryUsage()
        }
        #endif
    }
}

// MARK: - C Interop for Memory Info

import Darwin.Mach