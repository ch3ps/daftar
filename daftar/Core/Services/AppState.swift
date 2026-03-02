//
//  AppState.swift
//  daftar
//
//  Global app state
//

import SwiftUI
import Combine

final class AppState: ObservableObject {
    // MARK: - Language
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "app_language")
        }
    }
    
    // MARK: - Appearance
    @Published var appearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: "app_appearance")
        }
    }
    
    var colorScheme: ColorScheme? {
        switch appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    // MARK: - Layout Direction
    var layoutDirection: LayoutDirection {
        language == .arabic ? .rightToLeft : .leftToRight
    }
    
    init() {
        let savedLang = UserDefaults.standard.string(forKey: "app_language") ?? "ar"
        self.language = AppLanguage(rawValue: savedLang) ?? .arabic
        
        let savedAppearance = UserDefaults.standard.string(forKey: "app_appearance") ?? "system"
        self.appearance = AppAppearance(rawValue: savedAppearance) ?? .system
    }
    
    // MARK: - Localized Strings
    func localized(_ english: String, arabic: String) -> String {
        language == .arabic ? arabic : english
    }
}

// MARK: - App Appearance
enum AppAppearance: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    func displayName(localized: (_ english: String, _ arabic: String) -> String) -> String {
        switch self {
        case .system: return localized("System", "النظام")
        case .light: return localized("Light", "فاتح")
        case .dark: return localized("Dark", "داكن")
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

// MARK: - App Language
enum AppLanguage: String, Codable, CaseIterable {
    case english = "en"
    case arabic = "ar"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .arabic: return "العربية"
        }
    }
}
