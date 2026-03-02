//
//  DaftarApp.swift
//  daftar
//
//  Minimal, fast digital ledger for stores and customers
//

import SwiftUI
import UserNotifications

// MARK: - App Delegate for Push Notifications
class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        
        // Configure notification center delegate
        UNUserNotificationCenter.current().delegate = PushNotificationManager.shared
        
        // Initialize Sentry (uncomment and add SDK when ready)
        // SentrySDK.start { options in
        //     options.dsn = "YOUR_SENTRY_DSN"
        //     options.environment = "production"
        //     options.enableAutoSessionTracking = true
        //     options.tracesSampleRate = 0.1
        // }
        
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushNotificationManager.shared.didFailToRegisterForRemoteNotifications(error: error)
    }
}

@main
struct DaftarApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var authManager = AuthManager()
    @StateObject private var pushManager = PushNotificationManager.shared
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(authManager)
                .environmentObject(pushManager)
                .preferredColorScheme(appState.colorScheme)
                .task {
                    await pushManager.checkCurrentStatus()
                    setupPushTokenHandler()
                }
        }
    }
    
    private func setupPushTokenHandler() {
        pushManager.onTokenReceived = { token in
            Task {
                guard let userType = authManager.userType else { return }
                do {
                    if userType == .store {
                        try await APIClient.shared.registerStorePushToken(token)
                    } else {
                        try await APIClient.shared.registerCustomerPushToken(token)
                    }
                    print("[Push] Token registered with server")
                } catch {
                    print("[Push] Failed to register token: \(error)")
                }
            }
        }
    }
}

// MARK: - Root View
struct RootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager
    
    @State private var hasCompletedOnboarding = false
    
    var body: some View {
        Group {
            if !authManager.isAuthenticated {
                WelcomeView()
            } else if let userType = authManager.userType, shouldShowOnboarding(for: userType) {
                OnboardingView(userType: userType) {
                    markOnboardingComplete(for: userType)
                    hasCompletedOnboarding = true
                }
            } else {
                mainView
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
    }
    
    @ViewBuilder
    private var mainView: some View {
        if authManager.userType == .store {
            StoreMainView()
        } else {
            CustomerMainView()
        }
    }
    
    // MARK: - Onboarding Persistence
    
    private func shouldShowOnboarding(for type: UserType) -> Bool {
        if hasCompletedOnboarding { return false }
        
        let key = "has_seen_onboarding_\(type.rawValue)"
        return !UserDefaults.standard.bool(forKey: key)
    }
    
    private func markOnboardingComplete(for type: UserType) {
        let key = "has_seen_onboarding_\(type.rawValue)"
        UserDefaults.standard.set(true, forKey: key)
    }
}
