import Foundation
import os

/// Secure logging service that only logs in debug mode and filters sensitive information
final class LoggingService {
    static let shared = LoggingService()
    
    private init() {}
    
    // MARK: - Logging Categories
    
    private static let subsystem = "com.wikishorts.app"
    
    private lazy var generalLogger = os.Logger(subsystem: Self.subsystem, category: LogCategory.general.rawValue)
    private lazy var networkLogger = os.Logger(subsystem: Self.subsystem, category: LogCategory.network.rawValue)
    private lazy var cacheLogger = os.Logger(subsystem: Self.subsystem, category: LogCategory.storage.rawValue)
    private lazy var securityLogger = os.Logger(subsystem: Self.subsystem, category: LogCategory.security.rawValue)
    private lazy var adLogger = os.Logger(subsystem: Self.subsystem, category: LogCategory.adMob.rawValue)
    
    // MARK: - Logging Methods
    
    func logInfo(_ message: String, category: LogCategory = .general) {
        #if DEBUG
        getLogger(for: category).info("\(message)")
        #endif
    }
    
    func logWarning(_ message: String, category: LogCategory = .general) {
        getLogger(for: category).warning("\(message)")
    }
    
    func logError(_ message: String, category: LogCategory = .general) {
        getLogger(for: category).error("\(message)")
    }
    
    func logCritical(_ message: String, category: LogCategory = .general) {
        getLogger(for: category).critical("\(message)")
    }
    
    // MARK: - Specialized Logging Methods
    
    func logNetworkRequest(url: String, method: String = "GET") {
        #if DEBUG
        // Filter sensitive information from URLs
        let sanitizedURL = sanitizeURL(url)
        networkLogger.info("🌐 \(method) request to: \(sanitizedURL)")
        #endif
    }
    
    func logNetworkResponse(url: String, statusCode: Int, responseTime: TimeInterval? = nil) {
        #if DEBUG
        let sanitizedURL = sanitizeURL(url)
        if let responseTime = responseTime {
            networkLogger.info("📡 Response from \(sanitizedURL): \(statusCode) (\(String(format: "%.2f", responseTime))s)")
        } else {
            networkLogger.info("📡 Response from \(sanitizedURL): \(statusCode)")
        }
        #endif
    }
    
    func logCacheOperation(_ operation: String, key: String, category: LogCategory = .storage) {
        #if DEBUG
        let sanitizedKey = sanitizeKey(key)
        cacheLogger.info("🗄️ Cache \(operation): \(sanitizedKey)")
        #endif
    }
    
    func logSecurityEvent(_ event: String, details: String? = nil) {
        var message = "🔒 Security: \(event)"
        if let details = details {
            message += " - \(details)"
        }
        securityLogger.warning("\(message)")
    }
    
    func logAdEvent(_ event: String, details: String? = nil) {
        #if DEBUG
        var message = "💰 Ad: \(event)"
        if let details = details {
            message += " - \(details)"
        }
        adLogger.info("\(message)")
        #endif
    }
    
    // MARK: - Private Helpers
    
    // MARK: - Private Helpers
    
    private func getLogger(for category: LogCategory) -> os.Logger {
        switch category {
        case .general:
            return generalLogger
        case .network:
            return networkLogger
        case .storage:
            return cacheLogger
        case .security:
            return securityLogger
        case .adMob:
            return adLogger
        default:
            return generalLogger
        }
    }
    
    private func sanitizeURL(_ url: String) -> String {
        // Remove query parameters and sensitive path components
        guard let urlComponents = URLComponents(string: url) else { return "[Invalid URL]" }
        
        var sanitized = ""
        if let scheme = urlComponents.scheme {
            sanitized += "\(scheme)://"
        }
        if let host = urlComponents.host {
            sanitized += host
        }
        let path = urlComponents.path
        if !path.isEmpty {
            // Only show the first few path components
            let pathComponents = path.components(separatedBy: "/").prefix(3)
            sanitized += "/" + pathComponents.joined(separator: "/")
            if path.components(separatedBy: "/").count > 3 {
                sanitized += "/..."
            }
        }
        
        return sanitized
    }
    
    private func sanitizeKey(_ key: String) -> String {
        // Hash long keys to protect sensitive information
        if key.count > 50 {
            return "hash:\(key.hashValue)"
        }
        return key
    }
}

// MARK: - Log Categories

// MARK: - Log Categories
// LogCategory is defined in Logger.swift

// MARK: - Convenience Extensions

extension LoggingService {
    /// Log performance metrics
    func logPerformance(_ operation: String, duration: TimeInterval) {
        #if DEBUG
        let color = duration > 1.0 ? "🐌" : duration > 0.5 ? "⚠️" : "⚡"
        generalLogger.info("\(color) \(operation) took \(String(format: "%.3f", duration))s")
        #endif
    }
    
    /// Log memory usage
    func logMemoryUsage(_ component: String, bytes: Int64) {
        #if DEBUG
        let mb = Double(bytes) / (1024 * 1024)
        generalLogger.info("💾 \(component) memory usage: \(String(format: "%.2f", mb)) MB")
        #endif
    }
    
    /// Log user actions (be careful not to log personal data)
    func logUserAction(_ action: String) {
        #if DEBUG
        generalLogger.info("👤 User action: \(action)")
        #endif
    }
}