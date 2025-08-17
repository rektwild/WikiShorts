import Foundation

struct LanguageTestResult {
    let language: AppLanguage
    let isWorking: Bool
    let httpStatusCode: Int?
    let responseTime: TimeInterval?
    let errorDescription: String?
}

class WikipediaLanguageAPITester {
    static let shared = WikipediaLanguageAPITester()
    
    private init() {}
    
    func testAllLanguages() async -> [LanguageTestResult] {
        print("🧪 Starting Wikipedia API test for all \(AppLanguage.allCases.count) languages...")
        
        return await withTaskGroup(of: LanguageTestResult.self, returning: [LanguageTestResult].self) { group in
            for language in AppLanguage.allCases {
                group.addTask {
                    await self.testLanguageAPI(language: language)
                }
            }
            
            var results: [LanguageTestResult] = []
            for await result in group {
                results.append(result)
            }
            return results.sorted { $0.language.displayName < $1.language.displayName }
        }
    }
    
    private func testLanguageAPI(language: AppLanguage) async -> LanguageTestResult {
        let urlString = "https://\(language.rawValue).wikipedia.org/api/rest_v1/page/random/summary"
        
        guard let url = URL(string: urlString) else {
            return LanguageTestResult(
                language: language,
                isWorking: false,
                httpStatusCode: nil,
                responseTime: nil,
                errorDescription: "Invalid URL"
            )
        }
        
        let startTime = Date()
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10.0
            request.setValue("WikiShorts/1.0", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            let responseTime = Date().timeIntervalSince(startTime)
            
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0
            
            if statusCode == 200 {
                // Try to decode the response to ensure it's valid
                let decoder = JSONDecoder()
                let _ = try decoder.decode(RandomArticleResponse.self, from: data)
                
                return LanguageTestResult(
                    language: language,
                    isWorking: true,
                    httpStatusCode: statusCode,
                    responseTime: responseTime,
                    errorDescription: nil
                )
            } else {
                return LanguageTestResult(
                    language: language,
                    isWorking: false,
                    httpStatusCode: statusCode,
                    responseTime: responseTime,
                    errorDescription: "HTTP \(statusCode)"
                )
            }
            
        } catch {
            let responseTime = Date().timeIntervalSince(startTime)
            
            return LanguageTestResult(
                language: language,
                isWorking: false,
                httpStatusCode: nil,
                responseTime: responseTime,
                errorDescription: error.localizedDescription
            )
        }
    }
    
    func printTestResults(_ results: [LanguageTestResult]) {
        let workingLanguages = results.filter { $0.isWorking }
        let failedLanguages = results.filter { !$0.isWorking }
        
        print("\n📊 Wikipedia API Test Results")
        print("=" * 50)
        print("✅ Working Languages: \(workingLanguages.count)/\(results.count)")
        print("❌ Failed Languages: \(failedLanguages.count)/\(results.count)")
        print("🎯 Success Rate: \(String(format: "%.1f", Double(workingLanguages.count) / Double(results.count) * 100))%")
        
        if !workingLanguages.isEmpty {
            print("\n✅ WORKING LANGUAGES:")
            print("-" * 30)
            for result in workingLanguages.sorted(by: { $0.responseTime ?? 999 < $1.responseTime ?? 999 }) {
                let timeStr = result.responseTime.map { String(format: "%.2fs", $0) } ?? "N/A"
                print("  \(result.language.flag) \(result.language.displayName) (\(result.language.rawValue)) - \(timeStr)")
            }
        }
        
        if !failedLanguages.isEmpty {
            print("\n❌ FAILED LANGUAGES:")
            print("-" * 30)
            for result in failedLanguages {
                let errorStr = result.errorDescription ?? "Unknown error"
                let statusStr = result.httpStatusCode.map { " (HTTP \($0))" } ?? ""
                print("  \(result.language.flag) \(result.language.displayName) (\(result.language.rawValue)) - \(errorStr)\(statusStr)")
            }
        }
        
        // Group by error type
        let errorGroups = Dictionary(grouping: failedLanguages) { result in
            if let statusCode = result.httpStatusCode {
                return "HTTP \(statusCode)"
            }
            return result.errorDescription?.components(separatedBy: " ").first ?? "Unknown"
        }
        
        if !errorGroups.isEmpty {
            print("\n🔍 ERROR BREAKDOWN:")
            print("-" * 30)
            for (errorType, languages) in errorGroups.sorted(by: { $0.value.count > $1.value.count }) {
                print("  \(errorType): \(languages.count) languages")
                for lang in languages.prefix(3) {
                    print("    • \(lang.language.displayName) (\(lang.language.rawValue))")
                }
                if languages.count > 3 {
                    print("    • ... and \(languages.count - 3) more")
                }
            }
        }
    }
    
    func getWorkingLanguages(_ results: [LanguageTestResult]) -> Set<String> {
        return Set(results.filter { $0.isWorking }.map { $0.language.rawValue })
    }
    
    func getFailedLanguages(_ results: [LanguageTestResult]) -> Set<String> {
        return Set(results.filter { !$0.isWorking }.map { $0.language.rawValue })
    }
}

extension String {
    static func * (string: String, count: Int) -> String {
        return String(repeating: string, count: count)
    }
}