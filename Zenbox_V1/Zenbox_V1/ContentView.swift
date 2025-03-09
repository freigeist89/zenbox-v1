import SwiftUI
import CoreNFC
import SFSymbolsPicker
import FamilyControls
import ManagedSettings
import UserNotifications

// Add this extension near the top of the file, after the imports
extension Color {
    static let zenboxBlue = Color(hex: "09398A")
    static let zenboxTitleBlue = Color(hex: "0A5FF1")
    static let zenboxRed = Color(hex: "8A0939")
    // Add dark mode optimized colors
    static let zenboxDarkBackground = Color(hex: "121214")
    static let zenboxDarkCardBackground = Color(hex: "1E1E24")
    static let zenboxDarkAccent = Color(hex: "2A6AFF")
    static let zenboxDarkText = Color.white.opacity(0.95)
    static let zenboxDarkSecondaryText = Color.white.opacity(0.7)
}

// Add this extension to support hex color initialization
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 1)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Add this near the top of the file with the other color extensions
extension Color {
    static let accentColor = Color.zenboxBlue // Use zenboxBlue as the default accent color
}

// MARK: - Models
struct Session: Identifiable, Codable {
    var id: UUID
    let duration: TimeInterval
    let date: Date
    let profileName: String
    let profileIcon: String
    
    init(duration: TimeInterval, date: Date, profileName: String = "Fokus Modus", profileIcon: String = "moon.fill") {
        self.id = UUID()
        self.duration = duration
        self.date = date
        self.profileName = profileName
        self.profileIcon = profileIcon
    }
}

// MARK: - View Models
class TimerViewModel: ObservableObject, @unchecked Sendable {
    @Published var isSessionActive = false
    @Published var currentSessionTime: TimeInterval = 0
    @Published var lastSessionTime: TimeInterval = 00000// 01:03:27
    @Published var sessions: [Session] = []
    @Published var isScreenTimeAuthorized: Bool {
        didSet {
            UserDefaults.standard.set(isScreenTimeAuthorized, forKey: "isScreenTimeAuthorized")
        }
    }
    @Published var isNotificationsAuthorized: Bool = false
    @Published var currentStreak: Int = 0
    @Published var isStreakActive: Bool = true
    @Published var lastSessionDate: Date?
    @Published var targetSessionDuration: TimeInterval? {
        didSet {
            if let duration = targetSessionDuration {
                UserDefaults.standard.set(duration, forKey: targetSessionDurationKey)
            } else {
                UserDefaults.standard.removeObject(forKey: targetSessionDurationKey)
            }
        }
    }
    
    // Add reference to ProfileManager
    private weak var profileManager: ProfileManager?
    
    // Make timer visible for debugging (previously private)
    var timer: Timer?
    // Make startTime accessible for timer recovery
    var startTime: Date?
    private let sessionStateKey = "sessionState"
    private let sessionStartTimeKey = "sessionStartTime"
    private let sessionsKey = "savedSessions"
    private let lastSessionTimeKey = "lastSessionTime"
    private let targetSessionDurationKey = "targetSessionDuration"
    
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    // Add a reference to the AppBlocker
    private var appBlocker: AppBlocker?
    
    // Add function to set the app blocker reference
    func setAppBlocker(_ blocker: AppBlocker) {
        self.appBlocker = blocker
    }
    
    // Add function to set the profile manager reference
    func setProfileManager(_ manager: ProfileManager) {
        self.profileManager = manager
    }
    
    init() {
        // Load saved Screen Time authorization status
        self.isScreenTimeAuthorized = UserDefaults.standard.bool(forKey: "isScreenTimeAuthorized")
        
        // Request notification permissions
        requestNotificationAuthorization()
        
        // Add observer for Screen Time authorization changes
        NotificationCenter.default.addObserver(self, selector: #selector(handleAuthorizationChange), name: Notification.Name("ScreenTimeAuthorizationChanged"), object: nil)
        
        // Load streak data
        self.currentStreak = UserDefaults.standard.integer(forKey: "currentStreak")
        self.isStreakActive = UserDefaults.standard.bool(forKey: "isStreakActive")
        if let savedDate = UserDefaults.standard.object(forKey: "lastSessionDate") as? Date {
            self.lastSessionDate = savedDate
        }
        
        // Load target session duration if available
        if UserDefaults.standard.object(forKey: targetSessionDurationKey) != nil {
            self.targetSessionDuration = UserDefaults.standard.double(forKey: targetSessionDurationKey)
            // If stored value is 0, treat as nil (unlimited)
            if self.targetSessionDuration == 0 {
                self.targetSessionDuration = nil
            }
        } else {
            self.targetSessionDuration = nil
        }
        
        // Check if streak is still valid (needs to be updated daily)
        checkAndUpdateStreak()
        
        // Load saved last session time
        self.lastSessionTime = UserDefaults.standard.double(forKey: lastSessionTimeKey)
        
        // Load session history
        loadSessions()
        
        // Restore session state if app was closed during an active session
        restoreSessionIfNeeded()
        
        // Set up background task handling
        setupBackgroundTaskHandling()
    }
    
    // Method to handle Screen Time authorization changes
    @objc func handleAuthorizationChange() {
        // Get authorization status from AppBlocker if it exists
        if let appBlocker = appBlocker {
            self.isScreenTimeAuthorized = appBlocker.isAuthorized
            print("Screen Time authorization status updated: \(self.isScreenTimeAuthorized)")
        }
    }
    
    private func setupBackgroundTaskHandling() {
        // Register for app state notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc private func appWillResignActive() {
        // Save session state when app moves to background
        saveSessionState()
    }
    
    @objc private func appDidEnterBackground() {
        // Begin background task to ensure we have time to save state
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        
        // Save session state
        saveSessionState()
        
        // End background task when done
        endBackgroundTask()
    }
    
    @objc private func appWillTerminate() {
        // Last chance to save session state before the app terminates
        saveSessionState()
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    private func restoreSessionIfNeeded() {
        // Check if there was an active session when the app was closed
        if UserDefaults.standard.bool(forKey: sessionStateKey) {
            // Get the saved start time
            if let savedStartTimeData = UserDefaults.standard.object(forKey: sessionStartTimeKey) as? Data,
               let savedStartTime = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSDate.self, from: savedStartTimeData) {
                
                // Convert NSDate to Date
                let startDate = savedStartTime as Date
                
                // Calculate how much time has passed since the session started
                let elapsedTime = Date().timeIntervalSince(startDate)
                
                // Get the saved target duration if exists
                if UserDefaults.standard.object(forKey: targetSessionDurationKey) != nil {
                    let targetDuration = UserDefaults.standard.double(forKey: targetSessionDurationKey)
                    if targetDuration > 0 {
                        self.targetSessionDuration = targetDuration
                        
                        // Check if we already passed the target duration
                        if elapsedTime >= targetDuration {
                            // Session should have ended already
                            print("Restored session already exceeded target duration (\(targetDuration) seconds). Recording as completed session.")
                            
                            // Record the session
                            self.lastSessionTime = targetDuration // Use the target duration as the session length
                            UserDefaults.standard.set(targetDuration, forKey: lastSessionTimeKey)
                            
                            // Add to session history
                            let completedSession = Session(duration: targetDuration, date: startDate)
                            sessions.append(completedSession)
                            saveSessions()
                            
                            // Reset session state
                            resetSessionState()
                            return
                        }
                    } else {
                        self.targetSessionDuration = nil
                    }
                }
                
                // Only restore if the elapsed time is reasonable (prevent restoring very old sessions)
                if elapsedTime < 24 * 60 * 60 { // Less than 24 hours
                    // Restore the session
                    self.isSessionActive = true
                    self.startTime = startDate
                    self.currentSessionTime = elapsedTime
                    
                    // Use the common timer setup method
                    setupSessionTimer()
                    
                    print("Session timer restored - elapsed time: \(self.currentSessionTime)")
                    
                    // Log that we've restored the session
                    print("Session restored from previous state - start time: \(startDate)")
                } else {
                    // Session is too old, clean up and record it as a completed session
                    if elapsedTime > 0 && elapsedTime < 24 * 60 * 60 {
                        self.lastSessionTime = elapsedTime
                        UserDefaults.standard.set(elapsedTime, forKey: lastSessionTimeKey)
                        
                        // Add to session history
                        let completedSession = Session(duration: elapsedTime, date: startDate)
                        sessions.append(completedSession)
                        saveSessions()
                    }
                    
                    // Reset session state
                    resetSessionState()
                }
            } else {
                // Invalid saved state, reset it
                resetSessionState()
            }
        }
    }
    
    private func resetSessionState() {
        // Clear any active session state
        self.isSessionActive = false
        UserDefaults.standard.set(false, forKey: sessionStateKey)
        UserDefaults.standard.removeObject(forKey: sessionStartTimeKey)
    }
    
    private func saveSessionState() {
        // Save whether a session is active
        UserDefaults.standard.set(isSessionActive, forKey: sessionStateKey)
        
        // Save the start time if there is an active session
        if isSessionActive, let start = startTime {
            do {
                let startTimeData = try NSKeyedArchiver.archivedData(withRootObject: start as NSDate, requiringSecureCoding: true)
                UserDefaults.standard.set(startTimeData, forKey: sessionStartTimeKey)
                
                // Save target duration if set
                if let targetDuration = targetSessionDuration {
                    UserDefaults.standard.set(targetDuration, forKey: targetSessionDurationKey)
                }
            } catch {
                print("Error saving session start time: \(error)")
            }
        } else {
            // No active session, clear the start time
            UserDefaults.standard.removeObject(forKey: sessionStartTimeKey)
        }
    }
    
    private func saveSessions() {
        do {
            // Convert sessions to Data and save to UserDefaults
            let sessionsData = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(sessionsData, forKey: sessionsKey)
        } catch {
            print("Error encoding sessions: \(error)")
        }
    }
    
    private func loadSessions() {
        // Load sessions from UserDefaults
        if let sessionsData = UserDefaults.standard.data(forKey: sessionsKey) {
            do {
                let loadedSessions = try JSONDecoder().decode([Session].self, from: sessionsData)
                self.sessions = loadedSessions
            } catch {
                print("Error decoding sessions: \(error)")
            }
        }
    }
    
    func requestScreenTimeAuthorization() async {
        do {
            // Request authorization for individual device
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self.isScreenTimeAuthorized = true
            }
        } catch {
            print("Failed to authorize Screen Time: \(error.localizedDescription)")
            
            // Handle the error on main thread
            DispatchQueue.main.async {
                // Set authorization to false to ensure UI is consistent
                self.isScreenTimeAuthorized = false
                
                // Show an alert to the user
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    let alert = UIAlertController(
                        title: "Bildschirmzeit-Berechtigung fehlgeschlagen",
                        message: "Bitte erlaube Zenbox den Zugriff auf Bildschirmzeit in den Einstellungen.",
                        preferredStyle: .alert
                    )
                    
                    alert.addAction(UIAlertAction(title: "Einstellungen öffnen", style: .default) { _ in
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    })
                    
                    alert.addAction(UIAlertAction(title: "Abbrechen", style: .cancel))
                    
                    rootViewController.present(alert, animated: true)
                }
            }
        }
    }
    
    func startSession() {
        if !isScreenTimeAuthorized {
            Task {
                await requestScreenTimeAuthorization()
                
                // After authorization completes, check if it was successful
                if isScreenTimeAuthorized {
                    DispatchQueue.main.async {
                        self.startSessionInternal()
                    }
                }
            }
            return
        }
        
        startSessionInternal()
    }
    
    // Extract the actual session starting logic to a separate method
    private func startSessionInternal() {
        isSessionActive = true
        startTime = Date()
        
        // Use the common timer setup method
        setupSessionTimer()
        
        print("New session timer started")
        
        // Update streak when starting a session
        updateStreakForNewSession()
        
        // Schedule notification if target duration is set
        if let targetDuration = targetSessionDuration, isNotificationsAuthorized {
            scheduleSessionEndNotification(targetDuration: targetDuration)
        }
        
        // Save the session state
        saveSessionState()
    }
    
    func stopSession() {
        isSessionActive = false
        timer?.invalidate()
        timer = nil
        
        // Cancel any pending notifications when session stops
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        if let start = startTime {
            let duration = Date().timeIntervalSince(start)
            lastSessionTime = duration
            
            // Create session with current profile information
            let session = Session(
                duration: duration,
                date: start,
                profileName: profileManager?.currentProfile?.name ?? "Fokus Modus",
                profileIcon: profileManager?.currentProfile?.icon ?? "moon.fill"
            )
            sessions.append(session)
            
            // Save the last session time
            UserDefaults.standard.set(duration, forKey: lastSessionTimeKey)
            
            // Save updated sessions list
            saveSessions()
        }
        
        startTime = nil
        currentSessionTime = 0
        
        // Update the saved session state
        saveSessionState()
    }
    
    // Add this function to manage the streak
    private func checkAndUpdateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        guard let lastDate = lastSessionDate else {
            // No previous session, streak is inactive
            isStreakActive = false
            currentStreak = 0
            saveStreakData()
            return
        }
        
        let lastSessionDay = calendar.startOfDay(for: lastDate)
        let daysSinceLastSession = calendar.dateComponents([.day], from: lastSessionDay, to: today).day ?? 0
        
        if daysSinceLastSession > 1 {
            // Streak broken (more than 1 day since last session)
            isStreakActive = false
            currentStreak = 0
            saveStreakData()
        } else if daysSinceLastSession == 1 {
            // Yesterday was the last session, streak is still active
            isStreakActive = true
        }
        // If daysSinceLastSession is 0, it means the user already had a session today
    }
    
    // Add this function to save streak data
    private func saveStreakData() {
        UserDefaults.standard.set(currentStreak, forKey: "currentStreak")
        UserDefaults.standard.set(isStreakActive, forKey: "isStreakActive")
        UserDefaults.standard.set(lastSessionDate, forKey: "lastSessionDate")
    }
    
    // Add this function to update the streak for a new session
    private func updateStreakForNewSession() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastDate = lastSessionDate, 
           calendar.startOfDay(for: lastDate) == today {
            // Already had a session today, don't increment streak
            return
        }
        
        // Check if the streak is active or if we need to start a new one
        if isStreakActive || currentStreak == 0 {
            currentStreak += 1
            isStreakActive = true
        } else {
            // Streak was broken, start a new one
            currentStreak = 1
            isStreakActive = true
        }
        
        // Update last session date
        lastSessionDate = Date()
        
        // Save updated streak data
        saveStreakData()
    }
    
    // Add a common method for timer setup
    private func setupSessionTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Invalidate any existing timer first
            self.timer?.invalidate()
            
            // Create a new timer and make sure it's added to the main run loop
            self.timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let start = self.startTime else { return }
                self.currentSessionTime = Date().timeIntervalSince(start)
                
                // Check if we've reached the target duration (if set)
                if let targetDuration = self.targetSessionDuration, 
                   self.currentSessionTime >= targetDuration {
                    // Session duration reached, end the session
                    print("Target session duration reached (\(targetDuration) seconds). Ending session automatically.")
                    DispatchQueue.main.async {
                        self.stopSession()
                        
                        // Unblock apps when the session ends automatically
                        self.appBlocker?.unblockApps()
                        print("Apps unblocked after automatic session end")
                        
                        // Send push notification if authorized
                        if self.isNotificationsAuthorized {
                            self.sendSessionCompletedNotification(duration: targetDuration)
                        }
                        
                        // Show notification that session has ended
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootViewController = windowScene.windows.first?.rootViewController {
                            let alert = UIAlertController(
                                title: "🎉 Session erfolgreich abgeschlossen!",
                                message: "Großartig! Du hast deine geplante Session von \(formatTime(targetDuration)) gemeistert. Alle Apps sind jetzt wieder entsperrt. Sei stolz auf dich!",
                                preferredStyle: .alert
                            )
                            alert.addAction(UIAlertAction(title: "OK", style: .default))
                            rootViewController.present(alert, animated: true)
                        }
                    }
                }
            }
            
            // Ensure the timer is scheduled on the main run loop
            if let timer = self.timer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }
    
    // Add notification authorization request
    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { success, error in
            DispatchQueue.main.async {
                self.isNotificationsAuthorized = success
                if let error = error {
                    print("Notification authorization error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Add this function to send a notification when session completes
    private func sendSessionCompletedNotification(duration: TimeInterval) {
        // Check if notifications are enabled in settings
        if !isNotificationsAuthorized {
            return
        }
        
        // Get settings from settingsViewModel via UserDefaults
        let notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        let useSound = UserDefaults.standard.bool(forKey: "useNotificationSound")
        let useEmoji = UserDefaults.standard.bool(forKey: "useNotificationEmoji")
        
        if !notificationsEnabled {
            return
        }
        
        // Use the NotificationHelper to create content with cool emojis
        let content = NotificationHelper.createSessionCompletedContent(
            duration: duration,
            useEmoji: useEmoji,
            useSound: useSound
        )
        
        // Create an immediate trigger
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // Create the request with a unique identifier
        let request = UNNotificationRequest(
            identifier: "sessionCompleted-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        // Add the notification request
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling completion notification: \(error.localizedDescription)")
            } else {
                print("Session completion notification sent successfully")
            }
        }
    }
    
    // Add a function to schedule a notification for when the session will end
    func scheduleSessionEndNotification(targetDuration: TimeInterval) {
        // Check if notifications are enabled in settings
        if !isNotificationsAuthorized {
            return
        }
        
        // Get settings from settingsViewModel via UserDefaults
        let notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        let useSound = UserDefaults.standard.bool(forKey: "useNotificationSound")
        let useEmoji = UserDefaults.standard.bool(forKey: "useNotificationEmoji")
        
        if !notificationsEnabled {
            return
        }
        
        // Cancel any existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Use the NotificationHelper to create content with cool emojis
        let content = NotificationHelper.createSessionCompletedContent(
            duration: targetDuration,
            useEmoji: useEmoji,
            useSound: useSound
        )
        
        // Create a trigger for the exact time when the session should end
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: targetDuration, repeats: false)
        
        // Create the request
        let request = UNNotificationRequest(
            identifier: "sessionEnd",
            content: content,
            trigger: trigger
        )
        
        // Add the notification request
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled for \(targetDuration) seconds from now")
            }
        }
    }
}

// Add this new view model near the other view models
class SettingsViewModel: ObservableObject {
    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        }
    }
    
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
            // Request permissions if turning on
            if notificationsEnabled {
                requestNotificationPermissionsIfNeeded()
            }
        }
    }
    
    @Published var useNotificationSound: Bool {
        didSet {
            UserDefaults.standard.set(useNotificationSound, forKey: "useNotificationSound")
        }
    }
    
    @Published var useNotificationEmoji: Bool {
        didSet {
            UserDefaults.standard.set(useNotificationEmoji, forKey: "useNotificationEmoji")
        }
    }
    
    init() {
        // Check system dark mode setting
        let systemDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
        // Load saved preference or use system setting as default
        self.isDarkMode = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool ?? systemDarkMode
        
        // Load notification settings with default values
        self.notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        self.useNotificationSound = UserDefaults.standard.object(forKey: "useNotificationSound") as? Bool ?? true
        self.useNotificationEmoji = UserDefaults.standard.object(forKey: "useNotificationEmoji") as? Bool ?? true
    }
    
    private func requestNotificationPermissionsIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus != .authorized {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                    // We don't need to do anything with the result here
                }
            }
        }
    }
}

// MARK: - Custom Views
struct CircularProgressView: View {
    var progress: Double
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        // First check if settingsViewModel is properly initialized
        let isDarkMode = settingsViewModel.isDarkMode
        
        ZStack {
            // Background circle
            Circle()
                .stroke(lineWidth: 20)
                .opacity(isDarkMode ? 0.15 : 0.1)
                .foregroundColor(isDarkMode ? .zenboxDarkAccent : .zenboxBlue)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round))
                .foregroundColor(progress > 0.99 ? .zenboxRed : (isDarkMode ? .zenboxDarkAccent : .zenboxBlue))
                .rotationEffect(Angle(degrees: -90))
                .animation(.easeInOut(duration: 0.3), value: progress)
                .shadow(color: progress > 0.99 ? 
                        .zenboxRed.opacity(0.3) : 
                        (isDarkMode ? .zenboxDarkAccent.opacity(0.3) : .zenboxBlue.opacity(0.3)),
                        radius: isDarkMode ? 8 : 4)
        }
    }
}

// Then modify the TimerButton to include animations
struct TimerButton: View {
    var isActive: Bool
    var isScreenTimeAuthorized: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isActive {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Session beenden")
                        .font(.system(size: 16, weight: .semibold))
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 20, weight: .semibold))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Session starten")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text("NFC-Tag erforderlich")
                            .font(.system(size: 10))
                            .opacity(0.7)
                    }
                }
            }
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(
                isActive ?
                Color.zenboxRed :
                (isScreenTimeAuthorized ? Color.zenboxBlue : Color.gray)
            )
            .cornerRadius(30)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isScreenTimeAuthorized && !isActive)
    }
}

// MARK: - Helper Functions
func formatTime(_ timeInterval: TimeInterval) -> String {
    let hours = Int(timeInterval) / 3600
    let minutes = Int(timeInterval) / 60 % 60
    let seconds = Int(timeInterval) % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
}

// Helper function to format date and time for display
func formatDateTimeForDisplay(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE, HH:mm"
    formatter.locale = Locale(identifier: "de_DE") // Set German locale
    return formatter.string(from: date).uppercased()
}

// MARK: - Additional Views
struct ProfileView: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        NavigationView {
            // Use a simple placeholder view instead of AppSettingsView
            List {
                Section("Appearance") {
                    Toggle("Dark Mode", isOn: $settingsViewModel.isDarkMode)
                }
                
                Section("About") {
                    Text("Version 1.0")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Profil")
        }
    }
}

// Update the ProfilePickerView to accept a ProfileManager instance
struct ProfilePickerView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var profileManager: ProfileManager
    
    var body: some View {
        ProfilesPicker(profileManager: profileManager)
    }
}

// Add this struct near the other struct definitions
struct SessionDurationPicker: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: TimerViewModel
    @State private var selectedDuration: Int
    @State private var customDuration: Int = 0
    @State private var isCustomDuration: Bool = false
    
    private let predefinedDurations = [
        ("15 Minuten", 15 * 60),
        ("30 Minuten", 30 * 60),
        ("45 Minuten", 45 * 60),
        ("1 Stunde", 60 * 60),
        ("1,5 Stunden", 90 * 60),
        ("2 Stunden", 120 * 60),
        ("Benutzerdefiniert", -1),
        ("Unbegrenzt", 0)
    ]
    
    init(viewModel: TimerViewModel) {
        self.viewModel = viewModel
        
        // Initialize selectedDuration based on the current targetSessionDuration
        if let currentDuration = viewModel.targetSessionDuration {
            if let index = predefinedDurations.firstIndex(where: { $0.1 == Int(currentDuration) }) {
                _selectedDuration = State(initialValue: index)
                _isCustomDuration = State(initialValue: false)
            } else {
                _selectedDuration = State(initialValue: predefinedDurations.count - 2) // Custom duration
                _customDuration = State(initialValue: Int(currentDuration))
                _isCustomDuration = State(initialValue: true)
            }
        } else {
            _selectedDuration = State(initialValue: predefinedDurations.count - 1) // Unlimited
            _isCustomDuration = State(initialValue: false)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Wähle eine Sessiondauer")) {
                    List {
                        ForEach(0..<predefinedDurations.count, id: \.self) { index in
                            HStack {
                                Text(predefinedDurations[index].0)
                                Spacer()
                                if selectedDuration == index {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.zenboxBlue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedDuration = index
                                isCustomDuration = predefinedDurations[index].1 == -1
                            }
                        }
                    }
                }
                
                if isCustomDuration {
                    Section(header: Text("Benutzerdefinierte Dauer (Minuten)")) {
                        HStack {
                            Text("Minuten:")
                            TextField("Dauer in Minuten", text: Binding(
                                get: { String(customDuration) },
                                set: { if let value = Int($0) { customDuration = value } }
                            ))
                            .keyboardType(.numberPad)
                        }
                    }
                }
                
                Section {
                    Button("Bestätigen") {
                        saveDuration()
                        dismiss()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.zenboxBlue)
                }
            }
            .navigationTitle("Sessiondauer")
            .navigationBarItems(trailing: Button("Abbrechen") {
                dismiss()
            })
        }
    }
    
    private func saveDuration() {
        let duration: TimeInterval?
        
        if isCustomDuration {
            // Use custom duration in minutes
            duration = TimeInterval(customDuration * 60)
        } else {
            let selectedValue = predefinedDurations[selectedDuration].1
            
            if selectedValue == 0 {
                // Unlimited (nil)
                duration = nil
            } else {
                duration = TimeInterval(selectedValue)
            }
        }
        
        DispatchQueue.main.async {
            self.viewModel.targetSessionDuration = duration
        }
    }
}



// MARK: - Main View
struct ContentView: View {
    // Make sure StateObjects are initialized properly
    @StateObject private var viewModel = TimerViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()
    @StateObject private var profileManager = ProfileManager()
    @StateObject private var appBlocker = AppBlocker()
    
    // Rest of the ContentView properties
    @State private var showAddSession = false
    @State private var showProfileChangeTooltip = false
    @State private var showStreakTooltip = false
    @State private var showDurationPicker = false
    
    // Add the animation state variables here instead
    @State private var startButtonScale: CGFloat = 1.0
    @State private var startButtonRotation: Double = 0
    @State private var timerScale: CGFloat = 1.0
    @State private var timerOpacity: Double = 1.0
    
    // Add animation states for streak
    @State private var streakScale: CGFloat = 1.0
    @State private var streakRotation: Double = 0
    @State private var streakOpacity: Double = 1.0
    @State private var showStreakConfetti: Bool = false
    @State private var lastKnownStreak: Int = 0
    @State private var streakGlowRadius: CGFloat = 0
    @State private var streakGlowOpacity: Double = 0
    
    // Add state to track target duration changes for UI refresh
    @State private var lastTargetDuration: TimeInterval? = nil
    
    // For storing the last active profile
    private let lastActiveProfileKey = "lastActiveProfile"
    
    var body: some View {
        // Debug check for settingsViewModel
        let _ = print("SettingsViewModel initialized: true")
        
        TabView {
            // Timer View (Main View)
            VStack(spacing: 20) {
                // MARK: - Header
                header
                
                // MARK: - Timer Card
                ZStack {
                    // Enhanced card for better dark mode appearance
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            // Use a safer approach with nil coalescing
                            (settingsViewModel.isDarkMode == true) ? 
                            LinearGradient(
                                gradient: Gradient(colors: [Color.zenboxDarkCardBackground, Color.zenboxDarkCardBackground.opacity(0.9)]),
                                startPoint: .top,
                                endPoint: .bottom
                            ) :
                            LinearGradient(
                                gradient: Gradient(colors: [Color(uiColor: .systemBackground), Color(uiColor: .systemBackground)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(
                                    // Use a safer approach with nil coalescing
                                    (settingsViewModel.isDarkMode == true) ? 
                                    Color.white.opacity(0.07) : 
                                    Color.gray.opacity(0.1),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: (settingsViewModel.isDarkMode == true) ? 
                            .black.opacity(0.3) : 
                            .black.opacity(0.2),
                            radius: (settingsViewModel.isDarkMode == true) ? 20 : 15,
                            x: 0,
                            y: (settingsViewModel.isDarkMode == true) ? 8 : 5
                        )
                    VStack(spacing: 0) {
                        ZStack {
                            CircularProgressView(
                                progress: viewModel.isSessionActive ? 
                                    (viewModel.targetSessionDuration != nil ? 
                                        min(viewModel.currentSessionTime / viewModel.targetSessionDuration!, 1) : 
                                        min(viewModel.currentSessionTime / 3600, 1)) : 0
                            )
                            .frame(width: 260, height: 260)
                            
                            VStack(spacing: 0) {
                                Text(getSessionHeaderText(
                                    isActive: viewModel.isSessionActive,
                                    lastSessionTime: viewModel.lastSessionTime
                                ))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .gray)
                                    .tracking(1.2)
                                    .offset(y: -5)
                                
                                Text(viewModel.isSessionActive ?
                                     formatTime(viewModel.currentSessionTime) :
                                     formatTime(viewModel.lastSessionTime))
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkText : .primary)
                                    .monospacedDigit()
                                    .scaleEffect(timerScale)
                                    .opacity(timerOpacity)
                                
                                // Add elapsed percentage text
                                if viewModel.isSessionActive && viewModel.targetSessionDuration != nil {
                                    let percentage = min(viewModel.currentSessionTime / viewModel.targetSessionDuration!, 1) * 100
                                    Text("VERSTRICHEN (\(Int(percentage))%)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .gray)
                                        .tracking(1.2)
                                        .padding(.top, 4)
                                }
                                
                                Menu {
                                    ForEach(profileManager.profiles) { profile in
                                        Button(action: {
                                            profileManager.setCurrentProfile(id: profile.id)
                                            // Update the target session duration based on the selected profile
                                            viewModel.targetSessionDuration = profile.targetSessionDuration
                                            // Force UI refresh for start and goal times
                                            timerScale = 1.01
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                timerScale = 1.0
                                            }
                                        }) {
                                            Label {
                                                Text(profile.name)
                                            } icon: {
                                                Image(systemName: profile.icon)
                                            }
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    Button(action: {
                                        showAddSession = true
                                    }) {
                                        Label("Manage Profiles", systemImage: "gear")
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        if let currentProfile = profileManager.currentProfile as Profile? {
                                            Image(systemName: currentProfile.icon)
                                                .foregroundColor(viewModel.isSessionActive ? 
                                                                 (settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .gray) : 
                                                                 (settingsViewModel.isDarkMode ? .zenboxDarkAccent : .zenboxBlue))
                                                .font(.system(size: 12))
                                            Text(currentProfile.name)
                                                .foregroundColor(viewModel.isSessionActive ? 
                                                                 (settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .gray) : 
                                                                 (settingsViewModel.isDarkMode ? .zenboxDarkAccent : .zenboxBlue))
                                                .font(.system(size: 12))
                                        } else {
                                            Image(systemName: "tag.fill")
                                                .foregroundColor(viewModel.isSessionActive ? 
                                                                 (settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .gray) : 
                                                                 (settingsViewModel.isDarkMode ? .zenboxDarkAccent : .zenboxBlue))
                                                .font(.system(size: 12))
                                            Text("Select Profile")
                                                .foregroundColor(viewModel.isSessionActive ? 
                                                                 (settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .gray) : 
                                                                 (settingsViewModel.isDarkMode ? .zenboxDarkAccent : .zenboxBlue))
                                                .font(.system(size: 12))
                                        }
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(viewModel.isSessionActive ? 
                                                             (settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .gray) : 
                                                             (settingsViewModel.isDarkMode ? .zenboxDarkAccent : .zenboxBlue))
                                            .font(.system(size: 10))
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(
                                        settingsViewModel.isDarkMode ? 
                                        Color.black.opacity(0.3) : 
                                        Color(uiColor: .systemBackground)
                                    )
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(
                                                settingsViewModel.isDarkMode ? 
                                                Color.white.opacity(viewModel.isSessionActive ? 0.05 : 0.1) : 
                                                Color.zenboxBlue.opacity(viewModel.isSessionActive ? 0.1 : 0.3),
                                                lineWidth: 1
                                            )
                                    )
                                }
                                .disabled(viewModel.isSessionActive)
                                .overlay(
                                    viewModel.isSessionActive ?
                                    Text("Profile cannot be changed during active session")
                                        .font(.caption2)
                                        .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .gray)
                                        .padding(4)
                                        .background(
                                            settingsViewModel.isDarkMode ? 
                                            Color.black.opacity(0.5) : 
                                            Color(uiColor: .systemBackground)
                                        )
                                        .cornerRadius(4)
                                        .shadow(
                                            color: settingsViewModel.isDarkMode ? .black.opacity(0.5) : .black.opacity(0.2),
                                            radius: 2
                                        )
                                        .offset(y: 30)
                                        .opacity(0)
                                        .onHover { hovering in
                                            withAnimation {
                                                self.showProfileChangeTooltip = hovering
                                            }
                                        }
                                        .opacity(showProfileChangeTooltip ? 1 : 0)
                                    : nil
                                )
                                .padding(.top, 12)
                            }
                        }
                        .padding(.vertical, 20)
                        
                        // Add Started and Goal fields
                        VStack(spacing: 5) {
                            HStack(spacing: 20) {
                                VStack(spacing: 4) {
                                    Text("START")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .gray)
                                        .tracking(1.2)
                                    
                                    // Started time pill
                                    Text(getStartTimeText())
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkText : .primary)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 16)
                                        .background(
                                            Capsule()
                                                .fill(settingsViewModel.isDarkMode ? Color.black.opacity(0.4) : Color.gray.opacity(0.15))
                                        )
                                }
                                
                                Spacer()
                                
                                VStack(spacing: 4) {
                                    Text("ZIEL")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .gray)
                                        .tracking(1.2)
                                    
                                    // Goal time pill
                                    Text(getGoalTimeText())
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkText : .primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 16)
                                        .background(
                                            Capsule()
                                                .fill(settingsViewModel.isDarkMode ? Color.black.opacity(0.4) : Color.gray.opacity(0.15))
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        
                        if viewModel.isSessionActive {
                            // Use ZenboxNfcButton for stopping sessions as well
                            ZenboxNfcButton(
                                icon: "stop.circle.fill",
                                label: "Session beenden",
                                color: .zenboxRed,
                                onValidTag: {
                                    // This will only be called after valid NFC verification
                                    stopSession()
                                }
                            )
                            .padding(.horizontal)
                            .padding(.top, 20)
                        } else {
                            // Use ZenboxNfcButton for starting sessions only (removed the session duration button from here)
                            ZenboxNfcButton(
                                icon: "play.circle.fill",
                                label: "Session starten",
                                color: viewModel.isScreenTimeAuthorized ? .zenboxBlue : .gray,
                                onValidTag: {
                                    startSessionDirectly()
                                }
                            )
                            .disabled(!viewModel.isScreenTimeAuthorized)
                            .padding(.horizontal)
                            .padding(.top, 20)
                        }
                        
                        // Debug button - only visible in DEBUG mode
                        #if false // Hide debug buttons
                        if !viewModel.isSessionActive {
                            VStack(spacing: 8) {
                                Button("DEBUG: Force Start Session") {
                                    print("DEBUG: Force starting session")
                                    forceStartSession()
                                }
                                .padding(.top, 10)
                                .font(.caption)
                                .foregroundColor(.gray)
                                
                                Button("DEBUG: Ensure Default Profile") {
                                    print("DEBUG: Ensuring default profile exists")
                                    createDefaultProfileIfNeeded()
                                }
                                .font(.caption)
                                .foregroundColor(.gray)
                                
                                Button("DEBUG: Test Streak Animation") {
                                    print("DEBUG: Testing streak animation directly")
                                    // Always increment and animate without profile check
                                    testStreakIncrement()
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.top, 4)
                            }
                        }
                        #endif
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 10) // Add some padding to the top of the main view
            .background(
                settingsViewModel.isDarkMode ? 
                Color.zenboxDarkBackground : 
                Color(UIColor.systemGroupedBackground)
            )
            .tabItem {
                Image(systemName: "timer")
                Text("Timer")
            }
            
            // Stats View
            StatsView()
                .environmentObject(viewModel)
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Statistiken")
                }
            
            // Settings View
            NavigationView {
                SettingsView()
            }
            .tabItem {
                Image(systemName: "person.fill")
                Text("Einstellungen")
            }
        }
        .accentColor(.zenboxBlue)
        // Make sure environment objects are explicitly passed here
        .environmentObject(settingsViewModel)
        .environmentObject(appBlocker)
        .environmentObject(profileManager) 
        .environmentObject(viewModel)
        .preferredColorScheme(settingsViewModel.isDarkMode ? .dark : .light)
        .onAppear {
            print("ContentView appeared - checking session state")
            print("Session active: \(viewModel.isSessionActive)")
            print("Timer running: \(viewModel.timer != nil)")
            print("Current session time: \(viewModel.currentSessionTime)")
            print("App blocking state: \(appBlocker.isBlocking)")
            
            // Set the ProfileManager reference in the TimerViewModel
            viewModel.setProfileManager(profileManager)
            
            // Sync Screen Time authorization status from AppBlocker to TimerViewModel
            viewModel.isScreenTimeAuthorized = appBlocker.isAuthorized
            print("Screen Time authorization status: \(viewModel.isScreenTimeAuthorized)")
            
            // For unauthorized status, request authorization
            if !viewModel.isScreenTimeAuthorized {
                Task {
                    await appBlocker.requestAuthorization()
                    // Update ViewModel after requesting authorization
                    DispatchQueue.main.async {
                        viewModel.isScreenTimeAuthorized = appBlocker.isAuthorized
                        print("Updated Screen Time authorization status: \(viewModel.isScreenTimeAuthorized)")
                    }
                }
            }
            
            // Check notification authorization status
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    self.viewModel.isNotificationsAuthorized = (settings.authorizationStatus == .authorized)
                    print("Notification authorization status: \(settings.authorizationStatus.rawValue)")
                    
                    // Update notification settings in case the user changed permissions in iOS settings
                    if settings.authorizationStatus != .authorized {
                        // If not authorized, we should also disable notifications in settings
                        if self.settingsViewModel.notificationsEnabled {
                            print("Notifications disabled because authorization was revoked")
                            self.settingsViewModel.notificationsEnabled = false
                        }
                    }
                }
            }
            
            // Set the AppBlocker reference in the TimerViewModel
            viewModel.setAppBlocker(appBlocker)
            
            // Check if a profile is selected and update the session duration from the profile
            if !viewModel.isSessionActive, let currentProfile = profileManager.currentProfile {
                // Only update the view model's target session duration if there isn't one set already
                // or if we're not in an active session
                if viewModel.targetSessionDuration == nil && currentProfile.targetSessionDuration != nil {
                    viewModel.targetSessionDuration = currentProfile.targetSessionDuration
                    print("Applied profile's session duration: \(formatTime(currentProfile.targetSessionDuration!))")
                }
            }
            
            if let targetDuration = viewModel.targetSessionDuration {
                print("Target session duration: \(formatTime(targetDuration))")
            } else {
                print("No target session duration set (unlimited)")
            }
            
            // Check if a session was restored and ensure app blocking is consistent
            if viewModel.isSessionActive {
                print("Active session detected - ensuring app blocking")
                
                // Get the last active profile ID
                if let profileID = UserDefaults.standard.string(forKey: lastActiveProfileKey),
                   let profile = profileManager.profiles.first(where: { $0.id.uuidString == profileID }) {
                    print("Found profile: \(profile.name)")
                    
                    // Set it as the current profile if not already set
                    if profileManager.currentProfile == nil {
                        print("Setting current profile")
                        profileManager.setCurrentProfile(id: profile.id)
                    }
                    
                    // Ensure apps are blocked if session is active
                    if let currentProfile = profileManager.currentProfile, !appBlocker.isBlocking {
                        print("Ensuring apps are blocked")
                        appBlocker.blockApps(for: currentProfile)
                    }
                    
                    // Check if target duration has been reached
                    if let targetDuration = viewModel.targetSessionDuration,
                       viewModel.currentSessionTime >= targetDuration {
                        print("Target duration already reached - ending session")
                        viewModel.stopSession()
                        appBlocker.unblockApps()
                        
                        // Show notification
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootViewController = windowScene.windows.first?.rootViewController {
                            let alert = UIAlertController(
                                title: "🎉 Session erfolgreich abgeschlossen!",
                                message: "Großartig! Du hast deine geplante Session von \(formatTime(targetDuration)) gemeistert. Alle Apps sind jetzt wieder entsperrt. Sei stolz auf dich!",
                                preferredStyle: .alert
                            )
                            alert.addAction(UIAlertAction(title: "OK", style: .default))
                            rootViewController.present(alert, animated: true)
                        }
                    } else if let targetDuration = viewModel.targetSessionDuration {
                        // Re-schedule notification for the remaining time
                        let remainingTime = targetDuration - viewModel.currentSessionTime
                        if remainingTime > 0 && viewModel.isNotificationsAuthorized {
                            viewModel.scheduleSessionEndNotification(targetDuration: remainingTime)
                            print("Re-scheduled notification for remaining time: \(formatTime(remainingTime))")
                        }
                    }
                } else {
                    print("No profile found for active session")
                }
            } else if appBlocker.isBlocking {
                print("No active session but apps are blocked - unblocking apps")
                // If no active session but apps are still blocked, unblock them
                appBlocker.unblockApps()
                
                // Cancel any pending notifications
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            } else {
                // Double check that the app blocker state is consistent with UserDefaults
                print("No active session - ensuring blocker state is consistent")
                if UserDefaults.standard.bool(forKey: "isBlocking") != appBlocker.isBlocking {
                    print("WARNING: App blocker state inconsistent with UserDefaults - fixing")
                    if UserDefaults.standard.bool(forKey: "isBlocking") {
                        UserDefaults.standard.set(false, forKey: "isBlocking")
                    }
                    appBlocker.unblockApps()
                }
                
                // Cancel any pending notifications if there's no active session
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            }
            
            // As a safety measure, verify timer is running if session is active
            if viewModel.isSessionActive && viewModel.timer == nil {
                print("WARNING: Session is active but timer is nil - restarting timer")
                
                // Force restart the timer
                DispatchQueue.main.async {
                    if viewModel.startTime != nil {
                        viewModel.timer = Timer(timeInterval: 0.1, repeats: true) { [weak viewModel] _ in
                            guard let viewModel = viewModel, let startTime = viewModel.startTime else { return }
                            viewModel.currentSessionTime = Date().timeIntervalSince(startTime)
                        }
                        
                        if let timer = viewModel.timer {
                            RunLoop.main.add(timer, forMode: .common)
                            print("Timer restarted in onAppear")
                        }
                    } else {
                        print("ERROR: No start time available for active session")
                    }
                }
            }
            
            // Initialize lastKnownStreak when view appears
            lastKnownStreak = viewModel.currentStreak
            
            // Initialize lastTargetDuration
            lastTargetDuration = viewModel.targetSessionDuration
        }
        .sheet(isPresented: $showAddSession) {
            // Pass the shared profileManager instance to ProfilePickerView
            ProfilePickerView(profileManager: profileManager)
        }
        .sheet(isPresented: $showDurationPicker) {
            SessionDurationPicker(viewModel: viewModel)
        }
        .onChange(of: viewModel.targetSessionDuration) { oldValue, newValue in
            // Update lastTargetDuration when targetSessionDuration changes
            lastTargetDuration = newValue
            
            // Force UI refresh for start and goal times
            if oldValue != newValue {
                timerScale = 1.01
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    timerScale = 1.0
                }
            }
        }
    }
    
    private var header: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: viewModel.isStreakActive ? "flame.fill" : "flame")
                    .foregroundColor(viewModel.isStreakActive ? .green : .red)
                    .font(.system(size: 18))
                    .scaleEffect(streakScale)
                    .rotationEffect(.degrees(streakRotation))
                    .shadow(
                        color: viewModel.isStreakActive ? 
                        .green.opacity(settingsViewModel.isDarkMode ? streakGlowOpacity * 1.5 : streakGlowOpacity) : 
                        .red.opacity(settingsViewModel.isDarkMode ? streakGlowOpacity * 1.5 : streakGlowOpacity),
                        radius: settingsViewModel.isDarkMode ? streakGlowRadius * 1.5 : streakGlowRadius
                    )
                Text("\(viewModel.currentStreak)")
                    .foregroundColor(viewModel.isStreakActive ? .green : .red)
                    .fontWeight(.semibold)
                    .scaleEffect(streakScale)
                    .opacity(streakOpacity)
                    .shadow(
                        color: viewModel.isStreakActive ? 
                        .green.opacity(settingsViewModel.isDarkMode ? streakGlowOpacity * 1.5 : streakGlowOpacity) : 
                        .red.opacity(settingsViewModel.isDarkMode ? streakGlowOpacity * 1.5 : streakGlowOpacity),
                        radius: settingsViewModel.isDarkMode ? streakGlowRadius * 1.5 : streakGlowRadius
                    )
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        settingsViewModel.isDarkMode ? 
                        (viewModel.isStreakActive ? Color.green.opacity(0.15) : Color.red.opacity(0.15)) : 
                        (viewModel.isStreakActive ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    )
            )
            .overlay(
                GeometryReader { geometry in
                    VStack {
                        if showStreakConfetti {
                            ConfettiView()
                                .frame(width: 100, height: 100)
                                .offset(y: -50)
                        }
                        
                        Text(streakTooltipText)
                            .font(.caption2)
                            .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .gray)
                            .padding(4)
                            .background(
                                settingsViewModel.isDarkMode ? 
                                Color.black.opacity(0.7) : 
                                Color(uiColor: .systemBackground)
                            )
                            .cornerRadius(4)
                            .shadow(
                                color: settingsViewModel.isDarkMode ? .black.opacity(0.5) : .black.opacity(0.2),
                                radius: 2
                            )
                            .opacity(showStreakTooltip ? 1 : 0)
                            .position(x: geometry.size.width / 2, y: geometry.frame(in: .local).maxY + 20)
                    }
                }
            )
            .onHover { hovering in
                withAnimation {
                    showStreakTooltip = hovering
                }
            }
            .onChange(of: viewModel.currentStreak) { oldValue, newValue in
                if newValue > lastKnownStreak && lastKnownStreak > 0 {
                    // Animate streak increment
                    animateStreakIncrement()
                }
                lastKnownStreak = newValue
            }
            .onAppear {
                // Initialize lastKnownStreak when view appears
                lastKnownStreak = viewModel.currentStreak
            }
            
            Spacer()
            
            Text("Zenbox")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkAccent : .zenboxTitleBlue)
                .shadow(color: settingsViewModel.isDarkMode ? .zenboxDarkAccent.opacity(0.3) : .clear, radius: 2)
            
            Spacer()
            
            Button(action: {
                showAddSession = true
            }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18))
                    .foregroundColor(
                        viewModel.isSessionActive ? 
                        (settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .gray) : 
                        (settingsViewModel.isDarkMode ? .zenboxDarkAccent : .zenboxBlue)
                    )
                    .padding(8)
                    .background(
                        settingsViewModel.isDarkMode ? 
                        Color.black.opacity(0.3) : 
                        Color.gray.opacity(0.1)
                    )
                    .cornerRadius(15)
            }
            .disabled(viewModel.isSessionActive)
        }
        .padding()
    }
    
    private var streakTooltipText: String {
        if viewModel.isStreakActive {
            return viewModel.currentStreak == 1 ? 
                "Erster Tag deiner Streak!" : 
                "\(viewModel.currentStreak) Tage Streak! Weiter so!"
        } else {
            return "Starte heute eine Session, um deine Streak zu beginnen!"
        }
    }
    
    // Add this computed property to get the appropriate header text
    private func getSessionHeaderText(isActive: Bool, lastSessionTime: TimeInterval) -> String {
        if isActive {
            return "AKTIVE SESSION"
        } else if lastSessionTime == 0 {
            return "NEUE SESSION"
        } else {
            return "LETZTE SESSION"
        }
    }
    
    private func startSessionDirectly() {
        print("Starting session directly...")
        
        // Check if a session is already active
        guard !viewModel.isSessionActive else {
            // Show alert if session is already active
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                let alert = UIAlertController(
                    title: "Session bereits aktiv",
                    message: "Es läuft bereits eine Session. Beende diese zuerst, bevor du eine neue startest.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                rootViewController.present(alert, animated: true)
            }
            return
        }
        
        // Check if a profile is selected
        guard let currentProfile = profileManager.currentProfile else {
            // Show error alert if no profile is selected
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                let alert = UIAlertController(
                    title: "Kein Profil ausgewählt",
                    message: "Bitte wähle ein Profil aus, bevor du eine Session startest.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                rootViewController.present(alert, animated: true)
            }
            return
        }
        
        // Save the current profile ID for session restoration
        UserDefaults.standard.set(currentProfile.id.uuidString, forKey: lastActiveProfileKey)
        
        // Set the session duration from the profile if available
        if let profileDuration = currentProfile.targetSessionDuration {
            viewModel.targetSessionDuration = profileDuration
            print("Using profile's session duration: \(formatTime(profileDuration))")
        }
        
        // Add animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            timerScale = 1.1  // Slightly enlarge
            timerOpacity = 0.7  // Slightly fade
        }
        
        // Start session
        viewModel.startSession()
        
        // Block apps
        appBlocker.blockApps(for: currentProfile)
        
        // Return to normal after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                timerScale = 1.0
                timerOpacity = 1.0
            }
        }
        
        // Prepare duration message
        let durationMessage = viewModel.targetSessionDuration != nil ?
            " Die Session endet automatisch nach \(formatTime(viewModel.targetSessionDuration!))." : ""
        
        // Show success message
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            let alert = UIAlertController(
                title: "Session gestartet",
                message: "Die Session wurde erfolgreich mit dem Profil '\(currentProfile.name)' gestartet. Apps werden blockiert.\(durationMessage)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            rootViewController.present(alert, animated: true)
        }
    }
    
    // Function to stop the current session
    private func stopSession() {
        if viewModel.isSessionActive {
            // Add animation
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                timerScale = 0.9  // Slightly shrink
                timerOpacity = 0.7  // Slightly fade
            }
            
            // Get session duration before stopping
            let sessionDuration = viewModel.currentSessionTime
            
            // Stop session
            viewModel.stopSession()
            
            // Unblock apps
            appBlocker.unblockApps()
            
            // Return to normal after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    timerScale = 1.0
                    timerOpacity = 1.0
                }
            }
            
            // Show success message for ending session
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                let alert = UIAlertController(
                    title: "Session beendet",
                    message: "Deine Session wurde erfolgreich beendet. Dauer: \(formatTime(sessionDuration)). Apps sind wieder entsperrt.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                rootViewController.present(alert, animated: true)
            }
        }
    }
    
    private func animateStreakIncrement() {
        // Play a sequence of animations for streak increment
        
        // Step 1: Scale up, rotate, and add glow
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            streakScale = 1.5
            streakRotation = 20
            streakOpacity = 0.7
            streakGlowRadius = 10
            streakGlowOpacity = 0.8
        }
        
        // Step 2: Show confetti
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                showStreakConfetti = true
            }
        }
        
        // Step 3: Return to normal scale and rotation but keep glow
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                streakScale = 1.0
                streakRotation = 0
                streakOpacity = 1.0
            }
        }
        
        // Step 4: Slowly fade out glow
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 1.0)) {
                streakGlowRadius = 0
                streakGlowOpacity = 0
            }
        }
        
        // Step 5: Hide confetti after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showStreakConfetti = false
            }
        }
    }
    
    private func testNfcTag() {
        // Manual override for debugging
        let testTag = "BROKE-IS-GREAT"
        
        print("Using test tag: \(testTag)")
        
        DispatchQueue.main.async {
            if testTag == "BROKE-IS-GREAT" {
                self.startSessionDirectly()
            } else {
                // Show error alert
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    let alert = UIAlertController(
                        title: "Ungültiges NFC-Tag (Test)",
                        message: "Falsches Test-Tag: \(testTag)",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    rootViewController.present(alert, animated: true)
                }
            }
        }
    }
    
    
    // MARK: - Internal Testing Methods (Not visible in UI)
    
    // For testing streak animation - not visible in UI
    private func testStreakIncrement() {
        // Simulate a streak increment
        withAnimation {
            viewModel.currentStreak += 1
            viewModel.isStreakActive = true
            // This will trigger the animation via the onChange modifier
        }
    }
    
    // For testing session start without profile check - not visible in UI
    private func forceStartSession() {
        print("DEBUG: Force starting session without profile check")
        
        // Add animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            timerScale = 1.1  // Slightly enlarge
            timerOpacity = 0.7  // Slightly fade
        }
        
        // Start session directly - bypassing profile check
        viewModel.startSession()
        
        print("Session started (bypassing profile check)")
        
        // Return to normal after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                timerScale = 1.0
                timerOpacity = 1.0
            }
        }
    }
    
    // For creating default profile if needed - not visible in UI
    private func createDefaultProfileIfNeeded() {
        // Check if there's already a profile
        if profileManager.profiles.isEmpty || profileManager.currentProfile == nil {
            print("No profiles found or no current profile, creating default profile")
            
            // Create a default profile
            let defaultName = "Default Profile"
            profileManager.addProfile(name: defaultName, icon: "bell.slash")
            
            print("Created default profile: \(defaultName)")
            
            // Show confirmation
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                let alert = UIAlertController(
                    title: "Default Profile Created",
                    message: "A default profile has been created and selected.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                rootViewController.present(alert, animated: true)
            }
        } else {
            print("Profiles already exist: \(profileManager.profiles.count) profiles")
            print("Current profile: \(profileManager.currentProfile?.name ?? "None")")
            
            // Show current profile status
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                let alert = UIAlertController(
                    title: "Profile Status",
                    message: "Current profile: \(profileManager.currentProfile?.name ?? "None")\nTotal profiles: \(profileManager.profiles.count)",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                rootViewController.present(alert, animated: true)
            }
        }
    }
    
    // Helper methods for timestamp display
    private func getStartTimeText() -> String {
        if viewModel.isSessionActive, let startTime = viewModel.startTime {
            return formatDateTimeForDisplay(startTime)
        } else {
            return formatDateTimeForDisplay(Date())
        }
    }
    
    private func getGoalTimeText() -> String {
        // Use the lastTargetDuration state variable to ensure UI updates
        let duration = viewModel.targetSessionDuration
        
        if viewModel.isSessionActive, let startTime = viewModel.startTime, let duration = duration {
            // Active session with start time and duration
            return formatDateTimeForDisplay(startTime.addingTimeInterval(duration))
        } else if let duration = duration {
            // No active session but duration is set
            return formatDateTimeForDisplay(Date().addingTimeInterval(duration))
        } else {
            // No duration set
            return "UNBEGRENZT"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SettingsViewModel())
        .environmentObject(AppBlocker())
        .environmentObject(ProfileManager())
}

// MARK: - Confetti View
struct ConfettiView: View {
    let colors: [Color] = [.red, .blue, .green, .yellow, .pink, .purple, .orange]
    @State private var confettiPieces: [ConfettiPiece] = []
    
    struct ConfettiPiece: Identifiable {
        let id = UUID()
        var color: Color
        var startPosition: CGPoint
        var endPosition: CGPoint
        var size: CGFloat
        var rotation: Double
        var opacity: Double
        var shape: ConfettiShape
        var animationDuration: Double
        var animationDelay: Double
    }
    
    enum ConfettiShape {
        case circle, square, triangle
    }
    
    var body: some View {
        ZStack {
            ForEach(confettiPieces) { piece in
                confettiPieceView(for: piece)
                    .frame(width: piece.size, height: piece.size)
                    .modifier(FallingConfettiModifier(
                        startPosition: piece.startPosition,
                        endPosition: piece.endPosition,
                        rotation: piece.rotation,
                        opacity: piece.opacity,
                        duration: piece.animationDuration,
                        delay: piece.animationDelay
                    ))
            }
        }
        .onAppear {
            generateConfetti(count: 50)
        }
    }
    
    private func confettiPieceView(for piece: ConfettiPiece) -> some View {
        Group {
            switch piece.shape {
            case .circle:
                Circle()
                    .fill(piece.color)
            case .square:
                Rectangle()
                    .fill(piece.color)
            case .triangle:
                Triangle()
                    .fill(piece.color)
            }
        }
    }
    
    private func generateConfetti(count: Int) {
        confettiPieces = []
        
        for _ in 0..<count {
            let shape: ConfettiShape
            let random = Int.random(in: 0...2)
            if random == 0 {
                shape = .circle
            } else if random == 1 {
                shape = .square
            } else {
                shape = .triangle
            }
            
            // Start in the center
            let startPosition = CGPoint(x: 50, y: 50)
            
            // End at a random position at the border or beyond
            let angle = Double.random(in: 0...2 * .pi)
            let distance = Double.random(in: 50...150)
            let endX = 50 + cos(angle) * distance
            let endY = 50 + sin(angle) * distance + Double.random(in: 20...50) // Add extra Y for gravity effect
            
            let piece = ConfettiPiece(
                color: colors.randomElement()!,
                startPosition: startPosition,
                endPosition: CGPoint(x: endX, y: endY),
                size: CGFloat.random(in: 5...10),
                rotation: Double.random(in: 0...360),
                opacity: Double.random(in: 0.5...1.0),
                shape: shape,
                animationDuration: Double.random(in: 1.0...2.0),
                animationDelay: Double.random(in: 0...0.5)
            )
            
            confettiPieces.append(piece)
        }
    }
}

struct FallingConfettiModifier: ViewModifier {
    let startPosition: CGPoint
    let endPosition: CGPoint
    let rotation: Double
    let opacity: Double
    let duration: Double
    let delay: Double
    
    @State private var currentPosition: CGPoint
    @State private var currentRotation: Double = 0
    @State private var currentOpacity: Double = 0
    
    init(startPosition: CGPoint, endPosition: CGPoint, rotation: Double, opacity: Double, duration: Double, delay: Double) {
        self.startPosition = startPosition
        self.endPosition = endPosition
        self.rotation = rotation
        self.opacity = opacity
        self.duration = duration
        self.delay = delay
        
        // Initialize the @State variables
        _currentPosition = State(initialValue: startPosition)
        _currentRotation = State(initialValue: 0)
        _currentOpacity = State(initialValue: 0)
    }
    
    func body(content: Content) -> some View {
        content
            .position(x: currentPosition.x, y: currentPosition.y)
            .rotationEffect(.degrees(currentRotation))
            .opacity(currentOpacity)
            .onAppear {
                withAnimation(Animation.easeOut(duration: duration).delay(delay)) {
                    self.currentPosition = self.endPosition
                    self.currentRotation = self.rotation
                    self.currentOpacity = self.opacity
                }
                
                // Fade out at the end
                DispatchQueue.main.asyncAfter(deadline: .now() + duration + delay) {
                    withAnimation(.easeIn(duration: 0.3)) {
                        self.currentOpacity = 0
                    }
                }
            }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

