import Foundation
import AppTrackingTransparency
import UIKit
import Combine

enum ATTStatus {
    case authorized
    case denied
    case notDetermined
    case restricted
}

final class ATTManager: ObservableObject {
    static let shared = ATTManager()
    
    @Published var currentStatus: ATTStatus = .notDetermined
    private var didAttemptRequest = false
    private var hasStartedCoordination = false
    private var observer: NSObjectProtocol?
    
    private init() {
        updateCurrentStatus()
    }
    
    var isTrackingAuthorized: Bool {
        if #available(iOS 14, *) {
            return ATTrackingManager.trackingAuthorizationStatus == .authorized
        } else {
            return true
        }
    }
    
    /// Call this method to start the ATT coordination process
    /// It will listen for app becoming active and request permission at the right time
    func startATTCoordination() {
        guard !hasStartedCoordination else { return }
        hasStartedCoordination = true
        
        observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.requestPermissionIfNeeded()
        }
    }
    
    private func requestPermissionIfNeeded() {
        guard !didAttemptRequest else { return }
        didAttemptRequest = true
        
        if #available(iOS 14, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus
            if status == .notDetermined {
                // Small delay to ensure UI is ready, especially important on iPad
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.requestTrackingPermission { _ in }
                }
            } else {
                updateCurrentStatus()
            }
        } else {
            currentStatus = .authorized
        }
    }
    
    func requestTrackingPermission(completion: @escaping (ATTStatus) -> Void) {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    let attStatus: ATTStatus
                    switch status {
                    case .authorized:
                        attStatus = .authorized
                    case .denied:
                        attStatus = .denied
                    case .restricted:
                        attStatus = .restricted
                    case .notDetermined:
                        attStatus = .notDetermined
                    @unknown default:
                        attStatus = .denied
                    }
                    
                    self?.currentStatus = attStatus
                    completion(attStatus)
                    
                    // Notify other services that ATT permission has been handled
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ATTPermissionUpdated"),
                        object: nil,
                        userInfo: ["status": attStatus]
                    )
                }
            }
        } else {
            currentStatus = .authorized
            completion(.authorized)
        }
    }
    
    func getCurrentStatus() -> ATTStatus {
        if #available(iOS 14, *) {
            switch ATTrackingManager.trackingAuthorizationStatus {
            case .authorized:
                return .authorized
            case .denied:
                return .denied
            case .restricted:
                return .restricted
            case .notDetermined:
                return .notDetermined
            @unknown default:
                return .denied
            }
        } else {
            return .authorized
        }
    }
    
    private func updateCurrentStatus() {
        currentStatus = getCurrentStatus()
    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}