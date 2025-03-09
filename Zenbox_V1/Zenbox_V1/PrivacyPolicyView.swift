import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Datenschutzerklärung")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)
                
                Group {
                    Text("1. Einleitung")
                        .font(.headline)
                    
                    Text("Der Schutz Ihrer Privatsphäre ist uns wichtig. Diese Datenschutzerklärung informiert Sie darüber, wie wir mit Ihren persönlichen Daten umgehen, wenn Sie die Zenbox-App nutzen.")
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("2. Datenerhebung und -verwendung")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    Text("Die Zenbox-App sammelt keine persönlichen Daten. Alle Informationen über blockierte Apps und Sitzungen werden ausschließlich lokal auf Ihrem Gerät gespeichert und nicht an unsere Server übertragen.")
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("3. Lokale Datenspeicherung")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    Text("Die App speichert folgende Informationen lokal auf Ihrem Gerät:\n• Profile und blockierte Apps\n• Sitzungsdauer und -statistiken\n• App-Einstellungen")
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("4. Berechtigungen")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    Text("Die App benötigt Zugriff auf die Bildschirmzeit-Funktionen von iOS, um bestimmte Apps zu blockieren. Diese Berechtigungen werden nur für den vorgesehenen Zweck verwendet und keine Daten werden an Dritte weitergegeben.")
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("5. Datensicherheit")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    Text("Wir setzen angemessene technische und organisatorische Maßnahmen ein, um Ihre Daten zu schützen. Da alle Daten lokal auf Ihrem Gerät gespeichert werden, unterliegen sie den Sicherheitsmaßnahmen Ihres iOS-Geräts.")
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("6. Ihre Rechte")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    Text("Sie haben das Recht, Ihre Daten zu löschen. Dies können Sie jederzeit tun, indem Sie die App deinstallieren oder die App-Daten in den iOS-Einstellungen zurücksetzen.")
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
        .navigationTitle("Datenschutzerklärung")
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
        PrivacyPolicyView()
            .environmentObject(SettingsViewModel())
    }
}
