//
//  PushNotificationManager.swift
//  daftar
//
//  Handles push notification registration and FCM token management
//

import Foundation
import UserNotifications
import UIKit
import Combine

@MainActor
final class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()
    
    @Published var isAuthorized = false
    @Published var deviceToken: String?
    
    /// Callback for when device token is received
    var onTokenReceived: ((String) -> Void)?
    
    private override init() {
        super.init()
    }
    
    func requestAuthorization() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .badge, .sound]
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
            
            isAuthorized = granted
            
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            
            return granted
        } catch {
            print("[Push] Authorization error: \(error)")
            return false
        }
    }
    
    func checkCurrentStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }
    
    nonisolated func didRegisterForRemoteNotifications(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        
        Task { @MainActor in
            self.deviceToken = token
            print("[Push] Device token: \(token)")
            self.onTokenReceived?(token)
        }
    }
    
    nonisolated func didFailToRegisterForRemoteNotifications(error: Error) {
        print("[Push] Failed to register: \(error.localizedDescription)")
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension PushNotificationManager: UNUserNotificationCenterDelegate {
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        print("[Push] Notification tapped: \(userInfo)")
    }
}
