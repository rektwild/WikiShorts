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
                self.handleBackgroundAppRefresh(task: task as! BGAppRefreshTask)
            }
        }
        #endif
    }
    
    func scheduleBackgroundRefresh() {
        guard isBackgroundRefreshEnabled else {
            print("📱 Background refresh is disabled")
            return
        }
        
        #if canImport(BackgroundTasks)
        if #available(iOS 13.0, *) {
            let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
            request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes from now
            
            do {
                try BGTaskScheduler.shared.submit(request)
                print("🔄 Background refresh scheduled successfully")
            } catch {
                print("❌ Failed to schedule background refresh: \(error)")
            }
        }
        #endif
    }
    
    func handleBackgroundRefresh() async {
        print("🔄 Starting background refresh...")
        
        let selectedTopics = UserDefaults.standard.array(forKey: "selectedTopics") as? [String] ?? ["All Topics"]
        let languageCode = articleLanguageManager.languageCode
        
        do {
            // Preload articles for better user experience
            let articles = await articleRepository.preloadArticles(
                count: 5,
                topics: selectedTopics,
                languageCode: languageCode
            )
            
            // Preload images
            await articleRepository.preloadImages(for: articles)
            
            print("✅ Background refresh completed successfully - preloaded \(articles.count) articles")
        } catch {
            print("❌ Background refresh failed: \(error)")
        }
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
        
        // Create a task to handle the refresh
        let refreshTask = Task {
            await handleBackgroundRefresh()
        }
        
        // Provide the background task with an expiration handler
        task.expirationHandler = {
            refreshTask.cancel()
            task.setTaskCompleted(success: false)
        }
        
        // Execute the refresh
        Task {
            await handleBackgroundRefresh()
            task.setTaskCompleted(success: true)
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