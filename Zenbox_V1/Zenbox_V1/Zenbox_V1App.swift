//
//  Zenbox_V1App.swift
//  Zenbox_V1
//
//  Created by Konstantin Singer on 24.02.25.
//

import SwiftUI
import UserNotifications

// Add a notification handler class
class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    // Called when a notification is delivered to a foreground app
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               willPresent notification: UNNotification, 
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show the notification even when the app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Called when user taps on a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               didReceive response: UNNotificationResponse, 
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        if response.notification.request.content.categoryIdentifier == "SESSION_COMPLETED" {
            // Reset badge when user interacts with the notification
            UNUserNotificationCenter.current().setBadgeCount(0)
        }
        
        completionHandler()
    }
}

@main
struct Zenbox_V1App: App {
    @StateObject private var appBlocker = AppBlocker()
    
    // Add notification handler
    let notificationHandler = NotificationHandler()
    
    init() {
        // Set up notification categories and actions
        setupNotifications()
    }
    
    func setupNotifications() {
        // Set the delegate
        UNUserNotificationCenter.current().delegate = notificationHandler
        
        // Create notification category for session completion
        let category = UNNotificationCategory(
            identifier: "SESSION_COMPLETED",
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        // Register the category
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appBlocker)
        }
    }
}
