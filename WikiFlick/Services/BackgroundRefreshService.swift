import Foundation
import Combine
import UIKit
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

protocol BackgroundRefreshServiceProtocol {
    func scheduleBackgroundRefresh()
    func handleBackgroundRefresh() async
    func enableBackgroundRefresh(_ enabled: Bool)
}

class BackgroundRefreshService: BackgroundRefreshServiceProtocol {
    static let shared = BackgroundRefreshService()
    
    // Background task identifier
    private let backgroundTaskIdentifier = "com.wikiflick.refresh"
    
    // Dependencies
    private let articleRepository: ArticleRepositoryProtocol
    private let articleLanguageManager = ArticleLanguageManager.shared
    private let topicNormalizationService = TopicNormalizationService.shared
    
    // Settings
    private var isBackgroundRefreshEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "backgroundRefreshEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "backgroundRefreshEnabled")
        }
    }
    
    private init(articleRepository: ArticleRepositoryProtocol = ArticleRepository()) {
        self.articleRepository = articleRepository
        setupBackgroundTasks()
    }
    
    private func setupBackgroundTasks() {
        #if canImport(BackgroundTasks)
        if #available(iOS 13.0, *) {
            // Register background task
            BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
                guard let refreshTask = task as? BGAppRefreshTask else {
                    Logger.error("Invalid background task type: \(type(of: task))", category: .general)
                    task.setTaskCompleted(success: false)
                    return
                }
                self.handleBackgroundAppRefresh(task: refreshTask)
            }
        }
        #endif
    }
    
    func scheduleBackgroundRefresh() {
        guard isBackgroundRefreshEnabled else {
            Logger.info("Background refresh is disabled", category: .general)
            return
        }
        
        #if canImport(BackgroundTasks)
        if #available(iOS 13.0, *) {
            // Skip scheduling in simulator to avoid error logs
            #if targetEnvironment(simulator)
                Logger.info("Skipping background task scheduling in simulator", category: .general)
                return
            #else
            let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
            request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes from now
            
            do {
                try BGTaskScheduler.shared.submit(request)
                Logger.info("Background refresh scheduled successfully", category: .general)
            } catch {
                Logger.error("Failed to schedule background refresh: \(error)", category: .general)
            }
            #endif
        }
        #endif
    }
    
    func handleBackgroundRefresh() async {
        Logger.info("Starting background refresh...", category: .general)
        
        // Always get all topics -> categories
        let languageCode = articleLanguageManager.languageCode
        let allTopics = topicNormalizationService.getAllSupportedTopics()
        var categories = topicNormalizationService.getCategoriesForTopics(allTopics)
        categories = Array(categories.shuffled())

        // Preload articles using categories (better variety)
        let articles = await articleRepository.preloadCategoryBasedArticles(
            count: 5,
            categories: categories,
            languageCode: languageCode
        )
        
        // Preload images
        await articleRepository.preloadImages(for: articles)
        
        Logger.info("Background refresh completed successfully - preloaded \(articles.count) articles", category: .general)
    }
    
    func enableBackgroundRefresh(_ enabled: Bool) {
        isBackgroundRefreshEnabled = enabled
        
        if enabled {
            scheduleBackgroundRefresh()
        } else {
            // Cancel any pending background tasks
            #if canImport(BackgroundTasks)
            if #available(iOS 13.0, *) {
                BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskIdentifier)
            }
            #endif
        }
    }
    
    #if canImport(BackgroundTasks)
    @available(iOS 13.0, *)
    private func handleBackgroundAppRefresh(task: BGAppRefreshTask) {
        // Schedule the next background refresh
        scheduleBackgroundRefresh()
        
        // Create a single task to handle the refresh
        let refreshTask = Task {
            await handleBackgroundRefresh()
            task.setTaskCompleted(success: true)
        }
        
        // Provide the background task with an expiration handler
        task.expirationHandler = {
            refreshTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
    #endif
}

// MARK: - App Background Refresh Manager
class AppBackgroundManager: ObservableObject {
    @Published var isBackgroundRefreshEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isBackgroundRefreshEnabled, forKey: "backgroundRefreshEnabled")
            backgroundRefreshService.enableBackgroundRefresh(isBackgroundRefreshEnabled)
        }
    }
    
    private let backgroundRefreshService = BackgroundRefreshService.shared
    
    init() {
        self.isBackgroundRefreshEnabled = UserDefaults.standard.bool(forKey: "backgroundRefreshEnabled")
        
        // Enable by default for better UX
        if !UserDefaults.standard.bool(forKey: "backgroundRefreshInitialized") {
            self.isBackgroundRefreshEnabled = true
            UserDefaults.standard.set(true, forKey: "backgroundRefreshInitialized")
        }
    }
    
    func scheduleBackgroundRefresh() {
        backgroundRefreshService.scheduleBackgroundRefresh()
    }
    
    func handleBackgroundRefresh() async {
        await backgroundRefreshService.handleBackgroundRefresh()
    }
    
    func requestBackgroundPermissions() {
        // This will open Settings app for manual configuration
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

// MARK: - Background Refresh Notification Extension
extension Notification.Name {
    static let backgroundRefreshCompleted = Notification.Name("backgroundRefreshCompleted")
    static let backgroundRefreshFailed = Notification.Name("backgroundRefreshFailed")
}