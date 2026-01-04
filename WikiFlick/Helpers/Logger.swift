import Foundation
import os

enum LogCategory: String {
    case general = "General"
    case network = "Network"
    case ui = "UI"
    case storage = "Storage"
    case cache = "Cache"
    case wikipedia = "Wikipedia"
    case adMob = "AdMob"
    case ads = "Ads" // Alias for easier usage if needed, or distinct category
    case payment = "Payment"
    case security = "Security"
}

enum LogLevel {
    case debug, info, warning, error, fault
}

struct Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.wikishorts.app"
    
    static func debug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        log(message, level: .debug, category: category, file: file, function: function, line: line)
        #endif
    }
    
    static func info(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }

    static func warning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    static func error(_ message: String, category: LogCategory = .general, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var logMessage = message
        if let error = error {
            logMessage += " - Error: \(error.localizedDescription)"
        }
        log(logMessage, level: .error, category: category, file: file, function: function, line: line)
    }
    
    static func fault(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .fault, category: category, file: file, function: function, line: line)
    }
    
    private static func log(_ message: String, level: LogLevel, category: LogCategory, file: String, function: String, line: Int) {
        let logger = os.Logger(subsystem: subsystem, category: category.rawValue)
        let filename = (file as NSString).lastPathComponent
        let meta = "[\(filename):\(line)] \(function) -> "
        
        switch level {
        case .debug:
            logger.debug("\(meta, privacy: .public)\(message, privacy: .public)")
        case .info:
            logger.info("\(meta, privacy: .public)\(message, privacy: .public)")
        case .warning:
            logger.warning("\(meta, privacy: .public)\(message, privacy: .public)")
        case .error:
            logger.error("\(meta, privacy: .public)\(message, privacy: .public)")
        case .fault:
            logger.fault("\(meta, privacy: .public)\(message, privacy: .public)")
        }
    }
}
