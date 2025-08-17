import Foundation

class WikipediaAPITestRunner {
    static func runTests() async {
        print("🚀 Starting Wikipedia API Language Tests...")
        
        let tester = WikipediaLanguageAPITester.shared
        let results = await tester.testAllLanguages()
        
        tester.printTestResults(results)
        
        let workingLanguages = tester.getWorkingLanguages(results)
        let failedLanguages = tester.getFailedLanguages(results)
        
        print("\n💾 WORKING LANGUAGE CODES (for filtering):")
        print("Set([" + workingLanguages.sorted().map { "\"\($0)\"" }.joined(separator: ", ") + "])")
        
        print("\n🚫 FAILED LANGUAGE CODES (to exclude):")
        print("Set([" + failedLanguages.sorted().map { "\"\($0)\"" }.joined(separator: ", ") + "])")
        
        // Specific recommendations
        print("\n🎯 RECOMMENDATIONS:")
        print("-" * 40)
        
        if failedLanguages.contains("ceb") {
            print("• Cebuano (ceb) - Consider using 'tl' (Tagalog) as fallback")
        }
        if failedLanguages.contains("war") {
            print("• Waray (war) - Consider using 'tl' (Tagalog) as fallback")
        }
        if failedLanguages.contains("arz") {
            print("• Egyptian Arabic (arz) - Consider using 'ar' (Arabic) as fallback")
        }
        if failedLanguages.contains("yue") {
            print("• Cantonese (yue) - Consider using 'zh' (Chinese) as fallback")
        }
        if failedLanguages.contains("wuu") {
            print("• Wu Chinese (wuu) - Consider using 'zh' (Chinese) as fallback")
        }
        
        print("• Add timeout handling (10 seconds) for all API requests")
        print("• Implement fallback to English ('en') for failed languages")
        print("• Filter language picker to show only working languages")
        
        exit(0)
    }
}

// For command line testing - removed to fix compilation error
// This functionality is moved to the separate test_wikipedia_languages.swift file