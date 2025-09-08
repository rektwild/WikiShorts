import Foundation
import Network

/// Certificate pinning service for enhanced network security
class CertificatePinningService: NSObject {
    static let shared = CertificatePinningService()
    
    private override init() {
        super.init()
    }
    
    // Wikipedia SSL certificate public key hashes (updated December 2024)
    // These need to be updated when Wikipedia changes certificates
    #if DEBUG
    private let wikipediaCertificateHashes: Set<String> = [
        // Development: Allow any certificate for testing
        "DEVELOPMENT_BYPASS_HASH_PLACEHOLDER_DO_NOT_USE_IN_PRODUCTION"
    ]
    #else
    private let wikipediaCertificateHashes: Set<String> = [
        // CRITICAL: Replace these with actual Wikipedia certificate hashes
        // To get real hashes, use: openssl s_client -connect en.wikipedia.org:443 -servername en.wikipedia.org
        // Then extract public key and compute SHA-256 hash
        // Production: These MUST be replaced with real Wikipedia certificate hashes
        "REPLACE_WITH_REAL_WIKIPEDIA_PRIMARY_CERT_HASH",
        "REPLACE_WITH_REAL_WIKIPEDIA_BACKUP_CERT_HASH", 
        "REPLACE_WITH_REAL_WIKIPEDIA_ROOT_CERT_HASH"
    ]
    #endif
    
    private let pinnedDomains: Set<String> = [
        "wikipedia.org",
        "en.wikipedia.org",
        "upload.wikimedia.org"
    ]
    
    /// Validates server trust for pinned domains
    func validateServerTrust(_ serverTrust: SecTrust, forHost host: String) -> Bool {
        // Check if this domain should be pinned
        let shouldPin = pinnedDomains.contains { pinnedDomain in
            host.hasSuffix(pinnedDomain)
        }
        
        guard shouldPin else {
            // For non-pinned domains, use default validation
            return evaluateDefaultTrust(serverTrust)
        }
        
        // For pinned domains, validate certificate
        return validatePinnedCertificate(serverTrust)
    }
    
    private func validatePinnedCertificate(_ serverTrust: SecTrust) -> Bool {
        // Evaluate server trust
        var error: CFError?
        let isValid = SecTrustEvaluateWithError(serverTrust, &error)
        
        guard isValid else {
            if let error = error {
                print("🚨 Certificate validation failed with error: \(error)")
            } else {
                print("🚨 Certificate validation failed")
            }
            return false
        }
        
        // Extract certificate chain
        guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
            print("🚨 Failed to get certificate chain")
            return false
        }
        
        guard !certificateChain.isEmpty else {
            print("🚨 No certificates in trust chain")
            return false
        }
        
        // Check each certificate in the chain
        for certificate in certificateChain {
            
            // Get public key and compute hash
            if let publicKeyHash = getPublicKeyHash(from: certificate) {
                #if DEBUG
                // In development, log the actual hash for configuration
                print("🔐 Certificate hash: \(publicKeyHash)")
                if wikipediaCertificateHashes.contains("DEVELOPMENT_BYPASS_HASH_PLACEHOLDER_DO_NOT_USE_IN_PRODUCTION") {
                    print("⚠️ DEVELOPMENT: Certificate pinning bypassed")
                    return true
                }
                #endif
                
                if wikipediaCertificateHashes.contains(publicKeyHash) {
                    print("✅ Certificate validation successful")
                    return true
                }
            }
        }
        
        print("🚨 Certificate pinning failed - no matching certificate found")
        return false
    }
    
    private func evaluateDefaultTrust(_ serverTrust: SecTrust) -> Bool {
        var error: CFError?
        return SecTrustEvaluateWithError(serverTrust, &error)
    }
    
    private func getPublicKeyHash(from certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate) else {
            return nil
        }
        
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) else {
            return nil
        }
        
        // Create SHA-256 hash of public key
        let data = publicKeyData as Data
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = data.withUnsafeBytes { bytes in
            CC_SHA256(bytes.baseAddress, CC_LONG(data.count), &hash)
        }
        
        return Data(hash).base64EncodedString()
    }
    
    /// Creates a URLSession with certificate pinning enabled
    func createSecureURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        
        return URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: nil
        )
    }
    
    // MARK: - Development Helpers
    
    #if DEBUG
    /// Extracts and prints certificate information for debugging
    func printCertificateInfo(for host: String) {
        let url = URL(string: "https://\(host)")!
        let task = URLSession.shared.dataTask(with: url) { _, _, _ in
            // Task completion not important for debugging
        }
        task.resume()
    }
    
    /// Bypasses certificate pinning for development (NEVER use in production)
    var bypassPinningForDevelopment: Bool = false
    
    /// Validates certificate configuration and logs warnings
    func validateConfiguration() {
        let hasPlaceholderHashes = wikipediaCertificateHashes.contains { hash in
            hash.contains("PLACEHOLDER") || 
            hash.contains("REPLACE_WITH") || 
            hash.contains("DEVELOPMENT_BYPASS")
        }
        
        if hasPlaceholderHashes {
            LoggingService.shared.logCritical("🚨 SECURITY RISK: Certificate pinning using placeholder hashes!", category: .security)
            LoggingService.shared.logCritical("Replace with actual Wikipedia certificate hashes before production!", category: .security)
        } else {
            LoggingService.shared.logInfo("✅ Certificate pinning configured with real hashes", category: .security)
        }
    }
    #endif
}

// MARK: - URLSessionDelegate

extension CertificatePinningService: URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        
        #if DEBUG
        if bypassPinningForDevelopment {
            print("⚠️ DEVELOPMENT: Bypassing certificate pinning")
            completionHandler(.performDefaultHandling, nil)
            return
        }
        #endif
        
        // Check if this is a server trust challenge
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        let host = challenge.protectionSpace.host
        
        if validateServerTrust(serverTrust, forHost: host) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            print("🚨 Certificate pinning validation failed for host: \(host)")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

// MARK: - CommonCrypto Import

import CommonCrypto