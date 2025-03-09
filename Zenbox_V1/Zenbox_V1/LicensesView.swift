import SwiftUI

struct LicensesView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @State private var iconScale: CGFloat = 0.8
    @State private var iconOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with icon
                HStack {
                    Spacer()
                    VStack {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkAccent : .zenboxBlue)
                            .padding(24)
                            .background(
                                Circle()
                                    .fill(settingsViewModel.isDarkMode ? 
                                          Color.zenboxDarkCardBackground : 
                                          Color.white)
                                    .shadow(
                                        color: settingsViewModel.isDarkMode ? 
                                               Color.black.opacity(0.3) : 
                                               Color.gray.opacity(0.2),
                                        radius: 10,
                                        x: 0,
                                        y: 5
                                    )
                            )
                            .scaleEffect(iconScale)
                            .opacity(iconOpacity)
                            .padding(.bottom, 16)
                        
                        Text("Open-Source Lizenzen")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkText : .primary)
                            .opacity(textOpacity)
                            
                        Text("Verwendete Bibliotheken und Komponenten")
                            .font(.subheadline)
                            .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .secondary)
                            .padding(.top, 4)
                            .opacity(textOpacity)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
                
                // Broke Project
                VStack(alignment: .leading, spacing: 10) {
                    Text("Broke-Projekt")
                        .font(.headline)
                        .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkText : .primary)
                    
                    Text("Teile dieser App basieren auf dem Broke-Projekt")
                        .font(.footnote)
                        .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkText : .primary)
                    
                    Text("Copyright © 2024 Oz Tamir")
                        .font(.caption)
                        .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .secondary)
                    
                    Text("Lizenziert unter der Apache License, Version 2.0")
                        .font(.caption)
                        .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .secondary)
                    
                    Button(action: {
                        if let url = URL(string: "https://github.com/OzTamir/broke") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Text("Broke auf GitHub")
                                .font(.caption)
                                .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkAccent : .zenboxBlue)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkAccent : .zenboxBlue)
                        }
                    }
                    
                    Button(action: {
                        if let url = URL(string: "https://www.apache.org/licenses/LICENSE-2.0") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Text("Apache License 2.0")
                                .font(.caption)
                                .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkAccent : .zenboxBlue)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkAccent : .zenboxBlue)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(settingsViewModel.isDarkMode ? Color.zenboxDarkCardBackground : Color(UIColor.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(settingsViewModel.isDarkMode ? Color.white.opacity(0.07) : Color.gray.opacity(0.1), lineWidth: 1)
                )
                
                // SFSymbolsPickerForSwiftUI
                VStack(alignment: .leading, spacing: 10) {
                    Text("SFSymbolsPickerForSwiftUI")
                        .font(.headline)
                        .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkText : .primary)
                    
                    Text("Icon-Auswahl in der App")
                        .font(.footnote)
                        .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkText : .primary)
                    
                    Text("Copyright © 2023 Alessio Rubicini")
                        .font(.caption)
                        .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .secondary)
                    
                    Text("Lizenziert unter der MIT License")
                        .font(.caption)
                        .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .secondary)
                    
                    Button(action: {
                        if let url = URL(string: "https://github.com/alessiorubicini/SFSymbolsPickerForSwiftUI") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Text("SFSymbolsPickerForSwiftUI auf GitHub")
                                .font(.caption)
                                .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkAccent : .zenboxBlue)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkAccent : .zenboxBlue)
                        }
                    }
                    
                    Button(action: {
                        if let url = URL(string: "https://opensource.org/licenses/MIT") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Text("MIT License")
                                .font(.caption)
                                .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkAccent : .zenboxBlue)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkAccent : .zenboxBlue)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(settingsViewModel.isDarkMode ? Color.zenboxDarkCardBackground : Color(UIColor.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(settingsViewModel.isDarkMode ? Color.white.opacity(0.07) : Color.gray.opacity(0.1), lineWidth: 1)
                )
            }
            .padding()
        }
        .background(settingsViewModel.isDarkMode ? Color.zenboxDarkBackground : Color(UIColor.systemGroupedBackground))
        .navigationTitle("Lizenzen")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                textOpacity = 1.0
            }
        }
    }
}

#Preview {
    NavigationView {
        LicensesView()
            .environmentObject(SettingsViewModel())
    }
} 