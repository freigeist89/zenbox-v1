//
//  NfcButton.swift
//  Zenbox_V1
//
//  Created by Assistant on 23/08/2024.
//

import SwiftUI
import CoreNFC

struct NfcButton: View {
    @StateObject private var nfcReader = NFCReader()
    @State private var showNFCResult = false
    @State private var showNFCError = false
    @State private var nfcTagContent = ""
    @State private var errorMessage = ""
    
    var icon: String = "radiowaves.right"
    var label: String? = nil
    var color: Color = .zenboxBlue
    var onScan: ((String) -> Void)? = nil
    
    var body: some View {
        Button(action: {
            do {
                #if targetEnvironment(simulator)
                    // Display error for simulator
                    errorMessage = "NFC ist im Simulator nicht verfügbar. Bitte verwende ein echtes Gerät."
                    showNFCError = true
                #else
                    if NFCNDEFReaderSession.readingAvailable {
                        nfcReader.scan { result in
                            nfcTagContent = result
                            showNFCResult = true
                            if let onScan = onScan {
                                onScan(result)
                            }
                        }
                    } else {
                        errorMessage = "NFC ist auf diesem Gerät nicht verfügbar"
                        showNFCError = true
                    }
                #endif
            } catch {
                errorMessage = "NFC-Fehler: \(error.localizedDescription)"
                showNFCError = true
            }
        }) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                
                if let label = label {
                    Text(label)
                        .font(.system(size: 16))
                }
            }
            .foregroundColor(color)
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(15)
        }
        .alert("NFC Tag Inhalt", isPresented: $showNFCResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(nfcTagContent.isEmpty ? "Keine Inhalte gefunden" : nfcTagContent)
        }
        .alert("NFC Fehler", isPresented: $showNFCError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
}

// A more advanced NFC button that can also write to tags
struct NfcWriteButton: View {
    @StateObject private var nfcReader = NFCReader()
    @State private var showNFCResult = false
    @State private var resultMessage = ""
    @State private var showWriteDialog = false
    @State private var textToWrite = ""
    
    var icon: String = "radiowaves.right"
    var label: String? = nil
    var color: Color = .zenboxBlue
    var onComplete: ((Bool, String) -> Void)? = nil
    
    var body: some View {
        Button(action: {
            showWriteDialog = true
        }) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                
                if let label = label {
                    Text(label)
                        .font(.system(size: 16))
                }
            }
            .foregroundColor(color)
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(15)
        }
        .alert("Text auf NFC-Tag schreiben", isPresented: $showWriteDialog) {
            TextField("Text eingeben", text: $textToWrite)
            
            Button("Abbrechen", role: .cancel) { }
            
            Button("Schreiben") {
                if !textToWrite.isEmpty {
                    writeToTag()
                }
            }
        }
        .alert("NFC Ergebnis", isPresented: $showNFCResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(resultMessage)
        }
    }
    
    private func writeToTag() {
        nfcReader.write(textToWrite) { success in
            resultMessage = success ? "Erfolgreich geschrieben!" : "Schreiben fehlgeschlagen"
            showNFCResult = true
            
            if let onComplete = onComplete {
                onComplete(success, textToWrite)
            }
        }
    }
}

// MARK: - Preview
struct NfcButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            NfcButton()
            
            NfcButton(
                icon: "wave.3.right",
                label: "NFC scannen",
                color: .green
            )
            
            NfcWriteButton(
                icon: "square.and.pencil.circle",
                label: "NFC beschreiben",
                color: .orange
            )
        }
        .padding()
    }
}

// MARK: - Specialized Zenbox NFC Button
struct ZenboxNfcButton: View {
    @StateObject private var nfcReader = NFCReader()
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var nfcTagContent = ""
    
    var icon: String
    var label: String
    var color: Color
    var onValidTag: () -> Void
    
    init(
        icon: String = "wave.3.right.circle.fill",
        label: String = "NFC Tag scannen",
        color: Color = .zenboxBlue,
        onValidTag: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = label
        self.color = color
        self.onValidTag = onValidTag
    }
    
    var body: some View {
        Button(action: {
            scanNFCTag()
        }) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(label)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(color)
            .cornerRadius(15)
            .padding(.horizontal)
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func scanNFCTag() {
        nfcReader.scan { result in
            nfcTagContent = result
            
            if result == "BROKE-IS-GREAT" {
                // Valid tag detected
                alertTitle = "Gültiges Tag"
                alertMessage = "Zenbox Tag erkannt. Aktion wird ausgeführt."
                showAlert = true
                
                // Execute the provided action
                onValidTag()
            } else {
                // Invalid tag detected
                alertTitle = "Ungültiges Tag"
                alertMessage = "Das gescannte Tag enthält nicht den richtigen Code. Bitte verwende ein Tag mit 'BROKE-IS-GREAT'."
                showAlert = true
            }
        }
    }
} 
