import Foundation
import SwiftUI

// MARK: - App Error Types

enum AppError: Error, LocalizedError {
    case network(NetworkError)
    case repository(RepositoryError)
    case cache(String)
    case language(String)
    case settings(String)
    case permission(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .network(let networkError):
            return networkError.localizedDescription
        case .repository(let repositoryError):
            return repositoryError.localizedDescription
        case .cache(let message):
            return "Cache error: \(message)"
        case .language(let message):
            return "Language error: \(message)"
        case .settings(let message):
            return "Settings error: \(message)"
        case .permission(let message):
            return "Permission error: \(message)"
        case .unknown(let message):
            return message
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .network(.timeout):
            return "Check your internet connection and try again."
        case .network(.networkError):
            return "Please check your internet connection."
        case .network(.notFound):
            return "The content you're looking for is not available."
        case .language:
            return "Try switching to English or check language settings."
        case .cache:
            return "Clear app cache in Settings and restart the app."
        case .permission:
            return "Please allow the required permissions in Settings."
        default:
            return "Please try again or restart the app."
        }
    }
    
    var icon: String {
        switch self {
        case .network:
            return "wifi.slash"
        case .language:
            return "globe"
        case .cache:
            return "externaldrive"
        case .permission:
            return "hand.raised"
        case .settings:
            return "gearshape"
        default:
            return "exclamationmark.triangle"
        }
    }
    
    var category: ErrorCategory {
        switch self {
        case .network:
            return .network
        case .repository:
            return .data
        case .cache:
            return .cache
        case .language:
            return .localization
        case .settings:
            return .configuration
        case .permission:
            return .permission
        case .unknown:
            return .unknown
        }
    }
}

enum ErrorCategory {
    case network
    case data
    case cache
    case localization
    case configuration
    case permission
    case unknown
}

// MARK: - Error Handling Service

protocol ErrorHandlingServiceProtocol {
    func handle(error: Error, context: String?) -> AppError
    func shouldRetry(error: AppError) -> Bool
    func getRetryDelay(for error: AppError, attempt: Int) -> TimeInterval
    func logError(_ error: AppError, context: String?)
}

class ErrorHandlingService: ErrorHandlingServiceProtocol {
    static let shared = ErrorHandlingService()
    
    private let maxRetryAttempts = 3
    private let baseRetryDelay: TimeInterval = 2.0
    
    private init() {}
    
    func handle(error: Error, context: String? = nil) -> AppError {
        let appError: AppError
        
        switch error {
        case let networkError as NetworkError:
            appError = .network(networkError)
        case let repositoryError as RepositoryError:
            appError = .repository(repositoryError)
        case let urlError as URLError:
            appError = .network(mapURLError(urlError))
        default:
            appError = .unknown(error.localizedDescription)
        }
        
        logError(appError, context: context)
        return appError
    }
    
    func shouldRetry(error: AppError) -> Bool {
        switch error {
        case .network(.timeout), .network(.networkError):
            return true
        case .repository(.networkError):
            return true
        case .cache:
            return false
        case .language, .settings, .permission:
            return false
        default:
            return false
        }
    }
    
    func getRetryDelay(for error: AppError, attempt: Int) -> TimeInterval {
        guard attempt <= maxRetryAttempts else { return 0 }
        
        let multiplier = pow(2.0, Double(attempt - 1)) // Exponential backoff
        let jitter = Double.random(in: 0.8...1.2) // Add jitter to prevent thundering herd
        
        return baseRetryDelay * multiplier * jitter
    }
    
    func logError(_ error: AppError, context: String? = nil) {
        let contextString = context.map { " [Context: \($0)]" } ?? ""
        Logger.error("AppError [\(error.category)] \(error.localizedDescription)\(contextString)", category: .general)
        
        // In a production app, you might want to send this to a logging service
        // like Firebase Crashlytics or Sentry
        #if DEBUG
        Logger.debug("Error Details: \(error)", category: .general)
        #endif
    }
    
    private func mapURLError(_ error: URLError) -> NetworkError {
        switch error.code {
        case .timedOut:
            return .timeout
        case .notConnectedToInternet, .networkConnectionLost:
            return .networkError(error)
        case .badURL:
            return .invalidURL
        case .resourceUnavailable:
            return .notFound
        default:
            return .networkError(error)
        }
    }
}

// MARK: - Retry Manager

class RetryManager {
    private let errorHandler = ErrorHandlingService.shared
    private var retryAttempts: [String: Int] = [:]
    
    func executeWithRetry<T>(
        id: String,
        maxAttempts: Int = 3,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        let currentAttempt = (retryAttempts[id] ?? 0) + 1
        retryAttempts[id] = currentAttempt
        
        do {
            let result = try await operation()
            // Reset retry count on success
            retryAttempts[id] = 0
            return result
        } catch {
            let appError = errorHandler.handle(error: error, context: "Retry attempt \(currentAttempt) for \(id)")
            
            if currentAttempt < maxAttempts && errorHandler.shouldRetry(error: appError) {
                let delay = errorHandler.getRetryDelay(for: appError, attempt: currentAttempt)
                
                Logger.info("Retrying operation \(id) after \(delay)s (attempt \(currentAttempt)/\(maxAttempts))", category: .network)
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await executeWithRetry(id: id, maxAttempts: maxAttempts, operation: operation)
            } else {
                // Max attempts reached or non-retryable error
                retryAttempts[id] = 0
                throw appError
            }
        }
    }
    
    func resetRetryCount(for id: String) {
        retryAttempts[id] = 0
    }
}

// MARK: - Error Alert Manager

@MainActor
class ErrorAlertManager: ObservableObject {
    @Published var currentError: AppError?
    @Published var showingError = false
    
    private let errorHandler = ErrorHandlingService.shared
    
    func showError(_ error: Error, context: String? = nil) {
        let appError = errorHandler.handle(error: error, context: context)
        currentError = appError
        showingError = true
    }
    
    func showError(_ appError: AppError) {
        currentError = appError
        showingError = true
    }
    
    func dismissError() {
        currentError = nil
        showingError = false
    }
}

// MARK: - Error Alert View

struct ErrorAlertView: View {
    let error: AppError
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void
    
    @StateObject private var languageManager = AppLanguageManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: error.icon)
                .font(.system(size: 50))
                .foregroundColor(.red.opacity(0.8))
            
            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            
            HStack(spacing: 12) {
                Button("Dismiss") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                
                if let onRetry = onRetry, ErrorHandlingService.shared.shouldRetry(error: error) {
                    Button("Try Again") {
                        onRetry()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.9))
        )
        .padding(.horizontal, 40)
    }
}

// MARK: - Error Handling View Modifier

struct ErrorHandlingModifier: ViewModifier {
    @StateObject private var errorManager = ErrorAlertManager()
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: $errorManager.showingError) {
                Button("OK") {
                    errorManager.dismissError()
                }
            } message: {
                if let error = errorManager.currentError {
                    Text(error.localizedDescription)
                }
            }
            .environmentObject(errorManager)
    }
}

extension View {
    func withErrorHandling() -> some View {
        self.modifier(ErrorHandlingModifier())
    }
}