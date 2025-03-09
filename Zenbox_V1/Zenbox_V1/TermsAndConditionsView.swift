import SwiftUI

struct TermsAndConditionsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Nutzungsbedingungen")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)
                
                Group {
                    Text("1. Akzeptanz der Nutzungsbedingungen")
                        .font(.headline)
                    
                    Text("Durch die Nutzung der Zenbox-App akzeptieren Sie diese Nutzungsbedingungen. Wenn Sie mit diesen Bedingungen nicht einverstanden sind, verwenden Sie die App bitte nicht.")
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("2. Beschreibung des Dienstes")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    Text("Zenbox ist eine App zur Fokussierung und Produktivitätssteigerung, die es Benutzern ermöglicht, den Zugriff auf bestimmte Apps für festgelegte Zeiträume zu beschränken.")
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("3. Nutzung der App")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    Text("Sie dürfen die App nur für rechtmäßige Zwecke und in Übereinstimmung mit diesen Nutzungsbedingungen verwenden. Sie stimmen zu, die App nicht in einer Weise zu nutzen, die die Rechte anderer verletzen oder einschränken könnte.")
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("4. Haftungsbeschränkung")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    Text("Die App wird im vorliegenden Zustand ohne jegliche Garantie bereitgestellt. Wir übernehmen keine Haftung für direkte, indirekte, zufällige, besondere oder Folgeschäden, die sich aus der Nutzung oder der Unmöglichkeit der Nutzung der App ergeben.")
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("5. Änderungen der Nutzungsbedingungen")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    Text("Wir behalten uns das Recht vor, diese Nutzungsbedingungen jederzeit zu ändern. Die fortgesetzte Nutzung der App nach solchen Änderungen gilt als Ihre Zustimmung zu den geänderten Bedingungen.")
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Text("Letzte Aktualisierung: \(formattedCurrentDate())")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 16)
            }
            .padding()
        }
        .background(settingsViewModel.isDarkMode ? Color.zenboxDarkBackground : Color(UIColor.systemGroupedBackground))
        .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkText : .primary)
        .navigationTitle("Nutzungsbedingungen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { dismiss() }) {
                    Text("Fertig")
                }
            }
        }
    }
    
    private func formattedCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: Date())
    }
}

#Preview {
    NavigationView {
        TermsAndConditionsView()
            .environmentObject(SettingsViewModel())
    }
}
