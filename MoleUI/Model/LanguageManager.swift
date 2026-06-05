import Foundation
import ObjectiveC
import SwiftUI

/// Central language manager — single source of truth for the app's display language.
/// All localization goes through `LanguageManager.tr("key")` for instant switching.
/// Also uses object_setClass on Bundle.main as a safety net for any code that
/// calls Bundle.main.localizedString directly.
@Observable
final class LanguageManager: @unchecked Sendable {
    static let shared = LanguageManager()

    /// Current language code, e.g. "zh-Hans" or "en"
    var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "AppPreferredLanguage")
            updateLanguageBundle()
        }
    }

    /// Locale for `.environment(\.locale)` — drives date/number formatting
    var locale: Locale {
        Locale(identifier: currentLanguage)
    }

    /// The .lproj bundle for the current language. nil when using source language (en).
    private(set) var languageBundle: Bundle?

    init() {
        let stored = UserDefaults.standard.string(forKey: "AppPreferredLanguage")
        self.currentLanguage = stored ?? "zh-Hans"
        object_setClass(Bundle.main, LanguageBundle.self)
        updateLanguageBundle()
    }

    private func updateLanguageBundle() {
        if currentLanguage == "en" {
            languageBundle = nil
        } else if let url = Bundle.main.url(forResource: currentLanguage, withExtension: "lproj"),
                  let b = Bundle(url: url)
        {
            languageBundle = b
        } else {
            languageBundle = nil
        }
    }

    /// Localize a key using the current language bundle.
    /// This is the main localization entry point — use it everywhere.
    static func tr(_ key: String) -> String {
        let manager = shared
        if manager.currentLanguage == "en" {
            if let enBundle = manager.languageBundle {
                return enBundle.localizedString(forKey: key, value: nil, table: nil)
            }
            return key
        }
        if let bundle = manager.languageBundle {
            return bundle.localizedString(forKey: key, value: nil, table: nil)
        }
        return key
    }
}

/// Bundle subclass that overrides localizedString to use LanguageManager's selected language.
/// Applied to Bundle.main via object_setClass so all calls are intercepted.
class LanguageBundle: Bundle {
    @objc override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        let manager = LanguageManager.shared
        if manager.currentLanguage == "en" {
            if let enBundle = manager.languageBundle {
                return enBundle.localizedString(forKey: key, value: value, table: tableName)
            }
            return value ?? key
        }
        if let langBundle = manager.languageBundle {
            return langBundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}
