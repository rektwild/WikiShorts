import Foundation
import AppTrackingTransparency

enum ATTStatus {
    case authorized
    case denied
    case notDetermined
    case restricted
}

final class ATTManager {
    static let shared = ATTManager()
    
    private init() {}
    
    @Published var currentStatus: ATTStatus = .notDetermined
    
    var isTrackingAuthorized: Bool {
        if #available(iOS 14, *) {
            return ATTrackingManager.trackingAuthorizationStatus == .authorized
        } else {
            return true
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
}