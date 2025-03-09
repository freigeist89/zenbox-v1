//
//  AppBlocker.swift
//  Broke
//
//  Created by Oz Tamir on 22/08/2024.
//
import SwiftUI
import ManagedSettings
import FamilyControls

class AppBlocker: ObservableObject {
    let store = ManagedSettingsStore()
    @Published var isBlocking = false
    @Published var isAuthorized = false
    
    private let blockingShieldID = "com.yourcompany.zenbox.blockingShield"
    
    init() {
        loadBlockingState()
        Task {
            await requestAuthorization()
        }
    }
    
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            DispatchQueue.main.async {
                self.isAuthorized = true
                // Post notification that authorization status changed
                NotificationCenter.default.post(name: Notification.Name("ScreenTimeAuthorizationChanged"), object: nil)
            }
        } catch {
            print("Failed to request authorization: \(error)")
            DispatchQueue.main.async {
                self.isAuthorized = false
                // Post notification that authorization status changed
                NotificationCenter.default.post(name: Notification.Name("ScreenTimeAuthorizationChanged"), object: nil)
            }
        }
    }
    
    func toggleBlocking(for profile: Profile?) {
        guard let profile = profile, isAuthorized else {
            print("Not authorized to block apps or no profile provided")
            return
        }
        
        isBlocking.toggle()
        saveBlockingState()
        applyBlockingSettings(for: profile)
    }
    
    func applyBlockingSettings(for profile: Profile) {
        if isBlocking {
            NSLog("Blocking \(profile.appTokens.count) apps")
            store.shield.applications = profile.appTokens.isEmpty ? nil : profile.appTokens
            store.shield.applicationCategories = profile.categoryTokens.isEmpty ? ShieldSettings.ActivityCategoryPolicy.none : .specific(profile.categoryTokens)
        } else {
            store.shield.applications = nil
            store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.none
        }
    }
    
    private func loadBlockingState() {
        isBlocking = UserDefaults.standard.bool(forKey: "isBlocking")
    }
    
    private func saveBlockingState() {
        UserDefaults.standard.set(isBlocking, forKey: "isBlocking")
    }
    
    // Function to block apps from a specific profile
    func blockApps(for profile: Profile?) {
        guard let profile = profile else {
            print("Cannot block apps: No profile provided")
            return
        }
        
        print("Blocking apps for profile: \(profile.name)")
        
        // Create the selection
        var selection = FamilyActivitySelection()
        
        if !profile.appTokens.isEmpty {
            selection.applicationTokens = profile.appTokens
            print("Blocking \(profile.appTokens.count) apps")
        }
        
        if !profile.categoryTokens.isEmpty {
            selection.categoryTokens = profile.categoryTokens
            print("Blocking \(profile.categoryTokens.count) categories")
        }
        
        // Only proceed if there's something to block
        guard !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else {
            print("No apps or categories to block in this profile")
            return
        }
        
        // Apply the blocking - fix the Shield issue
        if !selection.applicationTokens.isEmpty {
            store.shield.applications = selection.applicationTokens
        }
        
        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
        }
        
        // Update blocking state
        isBlocking = true
        
        print("Apps successfully blocked for profile: \(profile.name)")
    }
    
    // Function to unblock all apps
    func unblockApps() {
        print("Unblocking all apps")
        
        // Remove all shields
        store.shield.applications = nil
        store.shield.applicationCategories = .none
        
        // Update blocking state
        isBlocking = false
        
        // Save the blocking state to UserDefaults
        saveBlockingState()
        
        print("Apps successfully unblocked")
    }
}
