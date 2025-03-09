import SwiftUI
import StoreKit
import FamilyControls
import ManagedSettings

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @EnvironmentObject var viewModel: TimerViewModel
    @State private var isStrictModeEnabled = false
    private let store = ManagedSettingsStore()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Notifications Section
                SettingsSectionView(title: "Benachrichtigungen") {
                    Toggle("Benachrichtigungen aktivieren", isOn: $settingsViewModel.notificationsEnabled)
                        .tint(settingsViewModel.isDarkMode ? .zenboxDarkAccent : .zenboxBlue)
                }
                
                // Appearance Section
                SettingsSectionView(title: "Aussehen") {
                    Toggle("Dark Mode", isOn: $settingsViewModel.isDarkMode)
                        .tint(settingsViewModel.isDarkMode ? .zenboxDarkAccent : .zenboxBlue)
                }

                // Strict Mode Section
                SettingsSectionView(title: "Strict Mode") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Strict Mode aktivieren", isOn: $isStrictModeEnabled)
                            .tint(settingsViewModel.isDarkMode ? .zenboxDarkAccent : .zenboxBlue)
                            .disabled(viewModel.isSessionActive)
                            .onChange(of: isStrictModeEnabled) { newValue in
                                if newValue {
                                    enableStrictMode()
                                } else {
                                    disableStrictMode()
                                }
                            }
                        
                        Text("Strict Mode verhindert das Deinstallieren der App während aktiver Sessions.")
                            .font(.caption)
                            .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                // Community Section
                SettingsSectionView(title: "Community") {
                    VStack(spacing: 16) {
                Button(action: {
                    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                          let rootViewController = windowScene.windows.first?.rootViewController else {
                        return
                    }
                    
                    let activityVC = UIActivityViewController(
                        activityItems: ["Check out Zenbox!"],
                        applicationActivities: nil
                    )
                    
                    if let presenter = rootViewController.presentedViewController {
                        presenter.present(activityVC, animated: true)
                    } else {
                        rootViewController.present(activityVC, animated: true)
                    }
                }) {
                            SettingsButtonView(
                                icon: "square.and.arrow.up",
                                title: "Mit einem Freund teilen",
                                isDarkMode: settingsViewModel.isDarkMode
                            )
                        }
                        
                        Button(action: suggestFeature) {
                            SettingsButtonView(
                                icon: "lightbulb",
                                title: "Feature vorschlagen",
                                isDarkMode: settingsViewModel.isDarkMode
                            )
                        }
                        
                        Button(action: reportBug) {
                            SettingsButtonView(
                                icon: "exclamationmark.triangle",
                                title: "Fehler melden",
                                isDarkMode: settingsViewModel.isDarkMode
                            )
                }
                
                Button(action: {
                    SKStoreReviewController.requestReview()
                }) {
                            SettingsButtonView(
                                icon: "star",
                                title: "Bewertung abgeben",
                                isDarkMode: settingsViewModel.isDarkMode
                            )
                        }
                    }
                }
                
                // Rechtliches Section
                SettingsSectionView(title: "Rechtliches") {
                    VStack(spacing: 16) {
                        NavigationLink(destination: TermsAndConditionsView()) {
                            SettingsButtonView(
                                icon: "doc.text",
                                title: "Nutzungsbedingungen",
                                isDarkMode: settingsViewModel.isDarkMode
                            )
                        }
                        
                        NavigationLink(destination: PrivacyPolicyView()) {
                            SettingsButtonView(
                                icon: "lock.shield",
                                title: "Datenschutzerklärung",
                                isDarkMode: settingsViewModel.isDarkMode
                            )
                        }
                        
                        NavigationLink(destination: LicensesView()) {
                            SettingsButtonView(
                                icon: "append.page",
                                title: "Lizenzen",
                                isDarkMode: settingsViewModel.isDarkMode
                            )
                        }
                    }
                }
            }
            .padding()
            
            // Version Info
            VStack(spacing: 4) {
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")
                    .font(.footnote)
                    .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .secondary)
                Text("Build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")")
                    .font(.caption2)
                    .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText.opacity(0.7) : .secondary.opacity(0.7))
            }
            .padding(.bottom, 8)
        }
        .background(settingsViewModel.isDarkMode ? Color.zenboxDarkBackground : Color(UIColor.systemGroupedBackground))
        .navigationTitle("Einstellungen")
        .navigationBarTitleDisplayMode(.large)
        .accentColor(settingsViewModel.isDarkMode ? .zenboxDarkAccent : .zenboxBlue)
    }
    
    private func enableStrictMode() {
        // Request authorization if needed
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                store.application.denyAppRemoval = true
                print("Strict Mode enabled: App removal denied.")
            } catch {
                print("Failed to authorize Screen Time: \(error.localizedDescription)")
            }
        }
    }
    
    private func disableStrictMode() {
        store.application.denyAppRemoval = false
        print("Strict Mode disabled: App removal allowed.")
    }
    
    private func getDeviceAndAppInfo() -> String {
        let deviceInfo = """
        
        --------------------
        App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
        Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
        Device: \(UIDevice.current.model)
        System Version: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)
        Device Name: \(UIDevice.current.name)
        """
        return deviceInfo
    }
    
    private func suggestFeature() {
        let recipient = "konstantin.singer@me.com"
        let subject = "Feature-Vorschlag Zenbox"
        let deviceInfo = getDeviceAndAppInfo()
        
        let emailBody = """
        Hallo Konstantin,
        
        ich hätte folgenden Vorschlag für Zenbox:\(deviceInfo)
        """
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = emailBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let mailtoString = "mailto:\(recipient)?subject=\(encodedSubject)&body=\(encodedBody)"
        
        if let mailtoUrl = URL(string: mailtoString), UIApplication.shared.canOpenURL(mailtoUrl) {
            UIApplication.shared.open(mailtoUrl)
        }
    }
    
    private func reportBug() {
        let recipient = "konstantin.singer@me.com"
        let subject = "Bug Report Zenbox"
        let deviceInfo = getDeviceAndAppInfo()
        
        let emailBody = """
        Hallo Konstantin,
        
        ich habe folgenden Bug in der App entdeckt:\(deviceInfo)
        """
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = emailBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let mailtoString = "mailto:\(recipient)?subject=\(encodedSubject)&body=\(encodedBody)"
        
        if let mailtoUrl = URL(string: mailtoString), UIApplication.shared.canOpenURL(mailtoUrl) {
            UIApplication.shared.open(mailtoUrl)
        }
    }
}

// MARK: - Supporting Views
struct SettingsSectionView<Content: View>: View {
    let title: String
    let content: Content
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkText : .primary)
            
            content
                            .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(settingsViewModel.isDarkMode ? Color.zenboxDarkCardBackground : Color(UIColor.systemBackground))
                        .shadow(
                            color: settingsViewModel.isDarkMode ? .black.opacity(0.3) : .black.opacity(0.1),
                            radius: settingsViewModel.isDarkMode ? 20 : 10,
                            x: 0,
                            y: settingsViewModel.isDarkMode ? 8 : 4
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(settingsViewModel.isDarkMode ? Color.white.opacity(0.07) : Color.gray.opacity(0.1), lineWidth: 1)
                )
        }
    }
}

struct SettingsButtonView: View {
    let icon: String
    let title: String
    let isDarkMode: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isDarkMode ? .zenboxDarkAccent : .zenboxBlue)
                .font(.system(size: 16))
            
            Text(title)
                .foregroundColor(isDarkMode ? .zenboxDarkText : .primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(isDarkMode ? .zenboxDarkSecondaryText.opacity(0.7) : .secondary.opacity(0.7))
                .font(.system(size: 14))
        }
    }
}
    
#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(SettingsViewModel())
    }
}

// MARK: - NFC App Blocking View
struct NFCBlockingView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var appBlocker: AppBlocker
    @State private var nfcTagContent: String = ""
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var isBlocking: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("NFC Tag App Blocking")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Text("Scanne ein NFC-Tag mit dem Code 'BROKE-IS-GREAT', um Apps zu blockieren oder zu entsperren.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Current status indicator
                VStack {
                    Text("Status")
                        .font(.headline)
                    
                    HStack {
                        Circle()
                            .fill(isBlocking ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                        
                        Text(isBlocking ? "Apps werden blockiert" : "Apps sind nicht blockiert")
                            .foregroundColor(isBlocking ? .green : .red)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                // Profiles section
                VStack(alignment: .leading) {
                    Text("Aktuelles Profil")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if let currentProfile = profileManager.currentProfile {
                        HStack {
                            Image(systemName: currentProfile.icon)
                            Text(currentProfile.name)
                            Spacer()
                            
                            if isBlocking {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.red)
                            } else {
                                Image(systemName: "lock.open.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    } else {
                        Text("Kein Profil ausgewählt")
                            .italic()
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
                .padding(.top)
                
                // NFC scan button
                ZenboxNfcButton(
                    icon: "wave.3.right.circle.fill",
                    label: "NFC Tag scannen",
                    color: .zenboxBlue,
                    onValidTag: {
                        // This will be called when a valid "BROKE-IS-GREAT" tag is detected
                        handleValidTag()
                    }
                )
                .padding(.top)
                
                // Last scan result
                if !nfcTagContent.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Letzter Scan:")
                            .font(.headline)
                        
                        Text(nfcTagContent)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                    }
                    .padding()
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            // Update the blocking status when the view appears
            isBlocking = appBlocker.isBlocking
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .navigationTitle("NFC App Blocking")
    }
    
    private func scanNFCTag() {
        let nfcReader = NFCReader()
        nfcReader.scan { result in
            self.nfcTagContent = result
            
            // Check if the tag content is the special code
            if result == "BROKE-IS-GREAT" {
                handleValidTag()
            } else {
                handleInvalidTag()
            }
        }
    }
    
    private func handleValidTag() {
        // Toggle app blocking
        if let currentProfile = profileManager.currentProfile {
            if isBlocking {
                // Currently blocking, so unblock
                appBlocker.unblockApps()
                isBlocking = false
                
                alertTitle = "Apps entsperrt"
                alertMessage = "Alle Apps wurden erfolgreich entsperrt."
            } else {
                // Currently not blocking, so block
                appBlocker.blockApps(for: currentProfile)
                isBlocking = true
                
                alertTitle = "Apps blockiert"
                alertMessage = "Apps wurden erfolgreich für das Profil '\(currentProfile.name)' blockiert."
            }
        } else {
            alertTitle = "Kein Profil ausgewählt"
            alertMessage = "Bitte wähle zuerst ein Profil aus, bevor du Apps blockierst."
        }
        
        showAlert = true
    }
    
    private func handleInvalidTag() {
        alertTitle = "Ungültiger Tag"
        alertMessage = "Der gescannte Tag enthält nicht den richtigen Code. Bitte verwende ein Tag mit dem Code 'BROKE-IS-GREAT'."
        showAlert = true
    }
}

// MARK: - NFC Quick Session View
struct NFCQuickSessionView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var appBlocker: AppBlocker
    @EnvironmentObject var viewModel: TimerViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 25) {
            Text("NFC Quick Session Start")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            
            Text("Scanne ein NFC-Tag mit dem Code 'BROKE-IS-GREAT', um eine Session direkt zu starten. Das aktuelle Profil wird verwendet, um Apps zu blockieren.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Current profile info
            if let currentProfile = profileManager.currentProfile {
                VStack {
                    Text("Aktuelles Profil")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: currentProfile.icon)
                            .foregroundColor(.zenboxBlue)
                        Text(currentProfile.name)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
            } else {
                VStack {
                    Text("Kein Profil ausgewählt")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    Text("Bitte wähle zuerst ein Profil aus")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            
            // Session status indicator
            VStack {
                Text("Session Status")
                    .font(.headline)
                
                HStack {
                    Circle()
                        .fill(viewModel.isSessionActive ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text(viewModel.isSessionActive ? "Session aktiv" : "Keine aktive Session")
                        .foregroundColor(viewModel.isSessionActive ? .green : .red)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            
            Spacer()
            
            // NFC scan button
            ZenboxNfcButton(
                icon: "play.circle.fill",
                label: "Session starten mit NFC",
                color: viewModel.isSessionActive ? .gray : .zenboxBlue,
                onValidTag: {
                    // This closure is called when a valid "BROKE-IS-GREAT" tag is detected
                    startSession()
                }
            )
            .disabled(viewModel.isSessionActive)
            .padding(.bottom, 40)
        }
        .padding()
        .navigationTitle("NFC Schnellstart")
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if alertTitle == "Session gestartet" {
                        // Navigate back to main screen after successful session start
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            )
        }
    }
    
    private func startSession() {
        guard !viewModel.isSessionActive else {
            alertTitle = "Session bereits aktiv"
            alertMessage = "Es läuft bereits eine Session. Beende diese zuerst, bevor du eine neue startest."
            showAlert = true
            return
        }
        
        guard let currentProfile = profileManager.currentProfile else {
            alertTitle = "Kein Profil ausgewählt"
            alertMessage = "Bitte wähle zuerst ein Profil aus, bevor du eine Session startest."
            showAlert = true
            return
        }
        
        // Start the session
        viewModel.startSession()
        
        // Block apps based on the current profile
        appBlocker.blockApps(for: currentProfile)
        
        // Show success message
        alertTitle = "Session gestartet"
        alertMessage = "Die Session wurde erfolgreich mit dem Profil '\(currentProfile.name)' gestartet. Apps werden blockiert."
        showAlert = true
    }
}
