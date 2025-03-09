import SwiftUI
import SFSymbolsPicker
import FamilyControls

// Add a reusable button view similar to SettingsButtonView
struct ProfileButtonView: View {
    let icon: String
    let title: String
    var value: String? = nil
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(colorScheme == .dark ? .zenboxDarkAccent : .zenboxBlue)
                .font(.system(size: 16))
            
            Text(title)
                .foregroundColor(colorScheme == .dark ? .zenboxDarkText : .primary)
            
            Spacer()
            
            if let value = value {
                Text(value)
                    .foregroundColor(colorScheme == .dark ? .zenboxDarkSecondaryText : .secondary)
            }
            
            Image(systemName: "chevron.right")
                .foregroundColor(colorScheme == .dark ? .zenboxDarkSecondaryText.opacity(0.7) : .secondary.opacity(0.7))
                .font(.system(size: 14))
        }
    }
}

struct ProfileFormView: View {
    @ObservedObject var profileManager: ProfileManager
    @State private var profileName: String
    @State private var profileIcon: String
    @State private var showSymbolsPicker = false
    @State private var showAppSelection = false
    @State private var showDurationPicker = false
    @State private var activitySelection: FamilyActivitySelection
    @State private var showDeleteConfirmation = false
    @State private var targetSessionDuration: TimeInterval?
    
    // Predefined durations for the picker
    private let predefinedDurations = [
        ("15 Minuten", 15 * 60),
        ("30 Minuten", 30 * 60),
        ("45 Minuten", 45 * 60),
        ("1 Stunde", 60 * 60),
        ("1,5 Stunden", 90 * 60),
        ("2 Stunden", 120 * 60),
        ("Unbegrenzt", 0)
    ]
    
    let profile: Profile?
    let onDismiss: () -> Void
    
    init(profile: Profile? = nil, profileManager: ProfileManager, onDismiss: @escaping () -> Void) {
        self.profile = profile
        self.profileManager = profileManager
        self.onDismiss = onDismiss
        _profileName = State(initialValue: profile?.name ?? "")
        _profileIcon = State(initialValue: profile?.icon ?? "bell.slash")
        _targetSessionDuration = State(initialValue: profile?.targetSessionDuration)
        
        var selection = FamilyActivitySelection()
        selection.applicationTokens = profile?.appTokens ?? []
        selection.categoryTokens = profile?.categoryTokens ?? []
        _activitySelection = State(initialValue: selection)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Modus-Details")) {
                    VStack(alignment: .leading) {
                        Text("Modus-Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Geben Sie den Modus-Namen ein", text: $profileName)
                    }
                    
                    Button(action: { showSymbolsPicker = true }) {
                        ProfileButtonView(
                            icon: profileIcon,
                            title: "Icon auswählen"
                        )
                    }
                }
                
                Section(header: Text("Sessiondauer")) {
                    Button(action: { showDurationPicker = true }) {
                        ProfileButtonView(
                            icon: "timer",
                            title: "Sessiondauer festlegen",
                            value: formatDurationText(targetSessionDuration)
                        )
                    }
                    
                    Text("Die Session läuft nach dieser Zeit ab. Du kannst dann die gesperrten Apps wieder verwenden ohne dich an deiner Zenbox auszuchecken.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("App-Konfiguration")) {
                    Button(action: { showAppSelection = true }) {
                        ProfileButtonView(
                            icon: "app.badge",
                            title: "Blockierte Apps konfigurieren"
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Blockierte Apps:")
                            Spacer()
                            Text("\(activitySelection.applicationTokens.count)")
                                .fontWeight(.bold)
                        }
                        HStack {
                            Text("Blockierte Kategorien:")
                            Spacer()
                            Text("\(activitySelection.categoryTokens.count)")
                                .fontWeight(.bold)
                        }
                        Text("Zenbox kann aufgrund von Datenschutzbedenken nicht die Namen der Apps auflisten, die in der Konfigurationsansicht ausgewählt wurden. Es kann nur die Anzahl der ausgewählten Apps sehen.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if profile != nil {
                    Section {
                        Button(action: { showDeleteConfirmation = true }) {
                            Text("Modus löschen")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle(profile == nil ? "Modus hinzufügen" : "Modus bearbeiten")
            .navigationBarItems(
                leading: Button("Abbrechen", action: onDismiss),
                trailing: Button("Speichern", action: handleSave)
                    .disabled(profileName.isEmpty)
            )
            .sheet(isPresented: $showSymbolsPicker) {
                SymbolsPicker(selection: $profileIcon, title: "Ein Icon auswählen", autoDismiss: true)
            }
            .sheet(isPresented: $showAppSelection) {
                NavigationView {
                    FamilyActivityPicker(selection: $activitySelection)
                        .navigationTitle("Apps auswählen")
                        .navigationBarItems(trailing: Button("Fertig") {
                            showAppSelection = false
                        })
                }
            }
            .sheet(isPresented: $showDurationPicker) {
                SessionDurationPickerView(duration: $targetSessionDuration) {
                    showDurationPicker = false
                }
            }
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text("Modus löschen"),
                    message: Text("Sind Sie sicher, dass Sie diesen Modus löschen möchten?"),
                    primaryButton: .destructive(Text("Löschen")) {
                        if let profile = profile {
                            profileManager.deleteProfile(withId: profile.id)
                        }
                        onDismiss()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    private func formatDurationText(_ duration: TimeInterval?) -> String {
        guard let duration = duration else {
            return "Unbegrenzt"
        }
        
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) Minuten"
        }
    }
    
    private func handleSave() {
        if let existingProfile = profile {
            profileManager.updateProfile(
                id: existingProfile.id,
                name: profileName,
                appTokens: activitySelection.applicationTokens,
                categoryTokens: activitySelection.categoryTokens,
                icon: profileIcon,
                targetSessionDuration: targetSessionDuration
            )
        } else {
            let newProfile = Profile(
                name: profileName,
                appTokens: activitySelection.applicationTokens,
                categoryTokens: activitySelection.categoryTokens,
                icon: profileIcon,
                targetSessionDuration: targetSessionDuration
            )
            profileManager.addProfile(newProfile: newProfile)
        }
        onDismiss()
    }
}

// Add a dedicated picker view for session duration
struct SessionDurationPickerView: View {
    @Binding var duration: TimeInterval?
    @State private var selectedHours = 0
    @State private var selectedMinutes = 0
    @State private var isUnlimited = false
    @Environment(\.colorScheme) var colorScheme
    let onDismiss: () -> Void
    
    init(duration: Binding<TimeInterval?>, onDismiss: @escaping () -> Void) {
        self._duration = duration
        self.onDismiss = onDismiss
        
        // Initialize time values based on current duration
        if let currentDuration = duration.wrappedValue {
            let totalMinutes = Int(currentDuration) / 60
            _selectedHours = State(initialValue: totalMinutes / 60)
            _selectedMinutes = State(initialValue: totalMinutes % 60)
            _isUnlimited = State(initialValue: false)
        } else {
            _selectedHours = State(initialValue: 0)
            _selectedMinutes = State(initialValue: 0)
            _isUnlimited = State(initialValue: true)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Wähle eine Sessiondauer")) {
                    Toggle("Unbegrenzte Dauer", isOn: $isUnlimited)
                        .tint(colorScheme == .dark ? .zenboxDarkAccent : .zenboxBlue)
                    
                    if !isUnlimited {
                        HStack {
                            Picker("Stunden", selection: $selectedHours) {
                                ForEach(0...23, id: \.self) { hour in
                                    Text("\(hour) Stunden").tag(hour)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(width: 150)
                            
                            Picker("Minuten", selection: $selectedMinutes) {
                                ForEach(0...59, id: \.self) { minute in
                                    Text("\(minute) Minuten").tag(minute)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(width: 150)
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        saveDuration()
                        onDismiss()
                    }) {
                        Text("Bestätigen")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(colorScheme == .dark ? Color.zenboxDarkAccent : Color.zenboxBlue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Sessiondauer")
            .navigationBarItems(trailing: Button("Abbrechen") {
                onDismiss()
            })
        }
    }
    
    private func saveDuration() {
        if isUnlimited {
            duration = nil
        } else {
            let totalSeconds = (selectedHours * 3600) + (selectedMinutes * 60)
            duration = TimeInterval(totalSeconds)
        }
    }
}

struct ProfileFormView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileFormView(profile: nil, profileManager: ProfileManager(), onDismiss: {})
    }
}
