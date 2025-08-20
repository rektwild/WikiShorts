import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable {
    case turkish = "tr"
    case english = "en"
    case german = "de"
    case french = "fr"
    case italian = "it"
    case chinese = "zh"
    case spanish = "es"
    case japanese = "ja"
    case cebuano = "ceb"
    case swedish = "sv"
    case dutch = "nl"
    case russian = "ru"
    case polish = "pl"
    case egyptianArabic = "arz"
    case ukrainian = "uk"
    case vietnamese = "vi"
    case arabic = "ar"
    case waray = "war"
    case portuguese = "pt"
    case persian = "fa"
    case catalan = "ca"
    case indonesian = "id"
    case korean = "ko"
    case serbian = "sr"
    case norwegian = "no"
    case chechen = "ce"
    case finnish = "fi"
    case czech = "cs"
    case hungarian = "hu"
    case malay = "ms"
    case hebrew = "he"
    case danish = "da"
    case bulgarian = "bg"
    case uzbek = "uz"
    case greek = "el"
    case hindi = "hi"
    case azerbaijani = "az"
    case georgian = "ka"
    case romanian = "ro"
    case thai = "th"
    case bangla = "bn"
    case croatian = "hr"
    case cantonese = "yue"
    case serboCroatian = "sh"
    case slovak = "sk"
    case tamil = "ta"
    case slovenian = "sl"
    case esperanto = "eo"
    case estonian = "et"
    case lithuanian = "lt"
    case urdu = "ur"
    case latin = "la"
    case malayalam = "ml"
    case afrikaans = "af"
    case basque = "eu"
    case albanian = "sq"
    case marathi = "mr"
    case bosnian = "bs"
    case kazakh = "kk"
    case galician = "gl"
    case armenian = "hy"
    case belarusian = "be"
    case wu = "wuu"
    case tagalog = "tl"
    case norwegianNynorsk = "nn"
    case telugu = "te"
    case asturian = "ast"
    case oldEnglish = "ang"
    case latvian = "lv"
    case burmese = "my"
    case macedonian = "mk"
    case scots = "sco"
    case alemannic = "als"
    case literaryChinese = "lzh"
    case icelandic = "is"
    case welsh = "cy"
    case irish = "ga"
    case luxembourgish = "lb"
    case sicilian = "scn"
    case turkmen = "tk"
    case mongolian = "mn"
    
    var displayName: String {
        switch self {
        case .turkish:
            return "Türkçe"
        case .english:
            return "English"
        case .german:
            return "Deutsch"
        case .french:
            return "Français"
        case .italian:
            return "Italiano"
        case .chinese:
            return "中文"
        case .spanish:
            return "Español"
        case .japanese:
            return "日本語"
        case .cebuano:
            return "Cebuano"
        case .swedish:
            return "Svenska"
        case .dutch:
            return "Nederlands"
        case .russian:
            return "Русский"
        case .polish:
            return "Polski"
        case .egyptianArabic:
            return "مصرى"
        case .ukrainian:
            return "Українська"
        case .vietnamese:
            return "Tiếng Việt"
        case .arabic:
            return "العربية"
        case .waray:
            return "Waray"
        case .portuguese:
            return "Português"
        case .persian:
            return "فارسی"
        case .catalan:
            return "Català"
        case .indonesian:
            return "Bahasa Indonesia"
        case .korean:
            return "한국어"
        case .serbian:
            return "Српски"
        case .norwegian:
            return "Norsk"
        case .chechen:
            return "Нохчийн мотт"
        case .finnish:
            return "Suomi"
        case .czech:
            return "Čeština"
        case .hungarian:
            return "Magyar"
        case .malay:
            return "Bahasa Melayu"
        case .hebrew:
            return "עברית"
        case .danish:
            return "Dansk"
        case .bulgarian:
            return "Български"
        case .uzbek:
            return "O'zbek"
        case .greek:
            return "Ελληνικά"
        case .hindi:
            return "हिन्दी"
        case .azerbaijani:
            return "Azərbaycan"
        case .georgian:
            return "ქართული"
        case .romanian:
            return "Română"
        case .thai:
            return "ไทย"
        case .bangla:
            return "বাংলা"
        case .croatian:
            return "Hrvatski"
        case .cantonese:
            return "粵語"
        case .serboCroatian:
            return "Srpskohrvatski"
        case .slovak:
            return "Slovenčina"
        case .tamil:
            return "தமிழ்"
        case .slovenian:
            return "Slovenščina"
        case .esperanto:
            return "Esperanto"
        case .estonian:
            return "Eesti keel"
        case .lithuanian:
            return "Lietuvių kalba"
        case .urdu:
            return "اردو"
        case .latin:
            return "Latina"
        case .malayalam:
            return "മലയാളം"
        case .afrikaans:
            return "Afrikaans"
        case .basque:
            return "Euskera"
        case .albanian:
            return "Shqip"
        case .marathi:
            return "मराठी"
        case .bosnian:
            return "Bosanski"
        case .kazakh:
            return "Қазақша"
        case .galician:
            return "Galego"
        case .armenian:
            return "Հայերեն"
        case .belarusian:
            return "Беларуская"
        case .wu:
            return "吳語"
        case .tagalog:
            return "Tagalog"
        case .norwegianNynorsk:
            return "Nynorsk"
        case .telugu:
            return "తెలుగు"
        case .asturian:
            return "Asturianu"
        case .oldEnglish:
            return "Ænglisc"
        case .latvian:
            return "Latviešu"
        case .burmese:
            return "မြန်မာ"
        case .macedonian:
            return "Македонски"
        case .scots:
            return "Scots"
        case .alemannic:
            return "Alemannisch"
        case .literaryChinese:
            return "文言"
        case .icelandic:
            return "Íslenska"
        case .welsh:
            return "Cymraeg"
        case .irish:
            return "Gaeilge"
        case .luxembourgish:
            return "Lëtzebuergesch"
        case .sicilian:
            return "Sicilianu"
        case .turkmen:
            return "Türkmençe"
        case .mongolian:
            return "Монгол"
        }
    }
    
    var flag: String {
        switch self {
        case .turkish:
            return "🇹🇷"
        case .english:
            return "🇺🇸"
        case .german:
            return "🇩🇪"
        case .french:
            return "🇫🇷"
        case .italian:
            return "🇮🇹"
        case .chinese:
            return "🇨🇳"
        case .spanish:
            return "🇪🇸"
        case .japanese:
            return "🇯🇵"
        case .cebuano:
            return "🇵🇭"
        case .swedish:
            return "🇸🇪"
        case .dutch:
            return "🇳🇱"
        case .russian:
            return "🇷🇺"
        case .polish:
            return "🇵🇱"
        case .egyptianArabic:
            return "🇪🇬"
        case .ukrainian:
            return "🇺🇦"
        case .vietnamese:
            return "🇻🇳"
        case .arabic:
            return "🇸🇦"
        case .waray:
            return "🇵🇭"
        case .portuguese:
            return "🇵🇹"
        case .persian:
            return "🇮🇷"
        case .catalan:
            return "🏴󠁥󠁳󠁣󠁴󠁿"
        case .indonesian:
            return "🇮🇩"
        case .korean:
            return "🇰🇷"
        case .serbian:
            return "🇷🇸"
        case .norwegian:
            return "🇳🇴"
        case .chechen:
            return "🏳️"
        case .finnish:
            return "🇫🇮"
        case .czech:
            return "🇨🇿"
        case .hungarian:
            return "🇭🇺"
        case .malay:
            return "🇲🇾"
        case .hebrew:
            return "🇮🇱"
        case .danish:
            return "🇩🇰"
        case .bulgarian:
            return "🇧🇬"
        case .uzbek:
            return "🇺🇿"
        case .greek:
            return "🇬🇷"
        case .hindi:
            return "🇮🇳"
        case .azerbaijani:
            return "🇦🇿"
        case .georgian:
            return "🇬🇪"
        case .romanian:
            return "🇷🇴"
        case .thai:
            return "🇹🇭"
        case .bangla:
            return "🇧🇩"
        case .croatian:
            return "🇭🇷"
        case .cantonese:
            return "🇭🇰"
        case .serboCroatian:
            return "🏳️"
        case .slovak:
            return "🇸🇰"
        case .tamil:
            return "🇱🇰"
        case .slovenian:
            return "🇸🇮"
        case .esperanto:
            return "🌍"
        case .estonian:
            return "🇪🇪"
        case .lithuanian:
            return "🇱🇹"
        case .urdu:
            return "🇵🇰"
        case .latin:
            return "🏛️"
        case .malayalam:
            return "🇮🇳"
        case .afrikaans:
            return "🇿🇦"
        case .basque:
            return "🏴"
        case .albanian:
            return "🇦🇱"
        case .marathi:
            return "🇮🇳"
        case .bosnian:
            return "🇧🇦"
        case .kazakh:
            return "🇰🇿"
        case .galician:
            return "🏴"
        case .armenian:
            return "🇦🇲"
        case .belarusian:
            return "🇧🇾"
        case .wu:
            return "🇨🇳"
        case .tagalog:
            return "🇵🇭"
        case .norwegianNynorsk:
            return "🇳🇴"
        case .telugu:
            return "🇮🇳"
        case .asturian:
            return "🏴"
        case .oldEnglish:
            return "🏛️"
        case .latvian:
            return "🇱🇻"
        case .burmese:
            return "🇲🇲"
        case .macedonian:
            return "🇲🇰"
        case .scots:
            return "🏴󠁧󠁢󠁳󠁣󠁴󠁿"
        case .alemannic:
            return "🇨🇭"
        case .literaryChinese:
            return "🇨🇳"
        case .icelandic:
            return "🇮🇸"
        case .welsh:
            return "🏴󠁧󠁢󠁷󠁬󠁳󠁿"
        case .irish:
            return "🇮🇪"
        case .luxembourgish:
            return "🇱🇺"
        case .sicilian:
            return "🇮🇹"
        case .turkmen:
            return "🇹🇲"
        case .mongolian:
            return "🇲🇳"
        }
    }
    
    var isWorkingWikipedia: Bool {
        // These languages have been tested and don't work with Wikipedia API
        let failedLanguages: Set<String> = ["lzh", "yue"]
        return !failedLanguages.contains(self.rawValue)
    }
    
    static var workingLanguages: [AppLanguage] {
        return AppLanguage.allCases.filter { $0.isWorkingWikipedia }
    }
    
    static func languageFromDisplayName(_ displayName: String) -> AppLanguage? {
        return AppLanguage.allCases.first { $0.displayName == displayName }
    }
}

class AppLanguageManager: ObservableObject {
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
            updateLocalizations()
            // Dil değişikliklerinde bildirimleri yenile
            NotificationManager.shared.refreshNotifications()
        }
    }
    
    static let shared = AppLanguageManager()
    
    private init() {
        let savedLanguage = UserDefaults.standard.string(forKey: "app_language") ?? "tr"
        self.currentLanguage = AppLanguage(rawValue: savedLanguage) ?? .turkish
        updateLocalizations()
    }
    
    private func updateLocalizations() {
        // Update bundle for localization
        Bundle.setLanguage(currentLanguage.rawValue)
    }
    
    func localizedString(key: String) -> String {
        return NSLocalizedString(key, comment: "")
    }
}

// Extension to support runtime language change
extension Bundle {
    static func setLanguage(_ language: String) {
        defer {
            object_setClass(Bundle.main, BundleEx.self)
        }
        
        objc_setAssociatedObject(Bundle.main, &bundleKey, Bundle(path: Bundle.main.path(forResource: language, ofType: "lproj") ?? ""), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

private var bundleKey: UInt8 = 0

class BundleEx: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let bundle = objc_getAssociatedObject(self, &bundleKey) as? Bundle else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

// Localization keys structure
struct LocalizationKeys {
    static let removeAds = "remove_ads"
    static let settings = "settings"
    static let searchWikipedia = "search_wikipedia"
    static let language = "language"
    static let about = "about"
    static let privacy = "privacy"
    static let terms = "terms"
    static let version = "version"
    static let adFree10Minutes = "ad_free_10_minutes"
    static let watchAd = "watch_ad"
    static let cancel = "cancel"
    static let ok = "ok"
    static let noAdAvailable = "no_ad_available"
    static let tryAgainLater = "try_again_later"
    static let backToFeed = "back_to_feed"
    static let learnMore = "learn_more"
    static let sponsoredContent = "sponsored_content"
    static let adIndicator = "ad"
    static let loadingArticles = "loading_articles"
    static let noArticlesAvailable = "no_articles_available"
    static let checkConnection = "check_connection"
    static let retry = "retry"
    static let somethingWentWrong = "something_went_wrong"
    static let tryAgain = "try_again"
    static let status = "status"
    static let accountStatus = "account_status"
    static let goPremium = "go_premium"
    static let preferences = "preferences"
    static let notifications = "notifications"
    static let wikiArticlePreferences = "wiki_article_preferences"
    static let topic = "topic"
    static let articleLanguage = "article_language"
    static let legal = "legal"
    static let termsOfService = "terms_of_service"
    static let privacyPolicy = "privacy_policy"
    static let appVersion = "app_version"
    static let rateApp = "rate_app"
    static let done = "done"
    static let topics = "topics"
    static let allTopics = "all_topics"
    static let generalReference = "general_reference"
    static let cultureAndArts = "culture_and_arts"
    static let geographyAndPlaces = "geography_and_places"
    static let healthAndFitness = "health_and_fitness"
    static let historyAndEvents = "history_and_events"
    static let humanActivities = "human_activities"
    static let mathematicsAndLogic = "mathematics_and_logic"
    static let naturalAndPhysicalSciences = "natural_and_physical_sciences"
    static let peopleAndSelf = "people_and_self"
    static let philosophyAndThinking = "philosophy_and_thinking"
    static let religionAndBeliefSystems = "religion_and_belief_systems"
    static let societyAndSocialSciences = "society_and_social_sciences"
    static let technologyAndAppliedSciences = "technology_and_applied_sciences"
    static let selected = "selected"
    static let wikishortsPro = "wikishorts_pro"
    static let adFreeExperience = "ad_free_experience"
    static let adFreeExperienceDesc = "ad_free_experience_desc"
    static let freeTrial = "free_trial"
    static let freeTrialDesc = "free_trial_desc"
    static let fasterLoading = "faster_loading"
    static let fasterLoadingDesc = "faster_loading_desc"
    static let oneMonth = "one_month"
    static let cancelAnytime = "cancel_anytime"
    static let loading = "loading"
    static let alreadySubscribed = "already_subscribed"
    static let startFreeTrial = "start_free_trial"
    static let restorePurchases = "restore_purchases"
    static let freeTrialThenPrice = "free_trial_then_price"
    static let error = "error"
    static let rewardedAd = "rewarded_ad"
    static let noAdFound = "no_ad_found"
}