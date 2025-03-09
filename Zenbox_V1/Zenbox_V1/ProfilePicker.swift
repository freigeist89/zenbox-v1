import SwiftUI
import FamilyControls

struct ProfilesPicker: View {
    @ObservedObject var profileManager: ProfileManager
    @State private var showAddProfileView = false
    @State private var editingProfile: Profile?
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            List {
                ForEach(profileManager.profiles) { profile in
                    HStack {
                        Image(systemName: profile.icon)
                            .foregroundColor(colorScheme == .dark ? .zenboxDarkAccent : .zenboxBlue)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.name)
                                .font(.body)
                            
                            Text("Apps: \(profile.appTokens.count) | Categories: \(profile.categoryTokens.count)")
                                .font(.caption)
                                .foregroundColor(colorScheme == .dark ? .zenboxDarkSecondaryText : .gray)
                        }
                        
                        Spacer()
                        
                        if profile.id == profileManager.currentProfileId {
                            Image(systemName: "checkmark")
                                .foregroundColor(colorScheme == .dark ? .zenboxDarkAccent : .blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        profileManager.setCurrentProfile(id: profile.id)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            // Show a confirmation dialog before deletion
                            if let index = profileManager.profiles.firstIndex(where: { $0.id == profile.id }) {
                                deleteProfile(at: index)
                            }
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                        .tint(.red)
                        
                        Button {
                            editingProfile = profile
                        } label: {
                            Label("Bearbeiten", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showAddProfileView = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                            .padding(6)
                            .background(colorScheme == .dark ? Color.zenboxDarkAccent : Color.zenboxBlue)
                            .clipShape(Circle())
                    }
                }
            }
            .sheet(item: $editingProfile) { profile in
                ProfileFormView(profile: profile, profileManager: profileManager) {
                    editingProfile = nil
                }
            }
            .sheet(isPresented: $showAddProfileView) {
                ProfileFormView(profileManager: profileManager) {
                    showAddProfileView = false
                }
            }
            .navigationTitle("Modes")
        }
    }
    
    // Function to handle profile deletion with confirmation
    private func deleteProfile(at index: Int) {
        // Get a reference to the profile
        let profileToDelete = profileManager.profiles[index]
        
        // Check if it's the current profile
        let isCurrentProfile = profileToDelete.id == profileManager.currentProfileId
        
        // Create and present a confirmation alert
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        let message = isCurrentProfile ? 
            "Dies ist das aktuell ausgewählte Profil. Möchtest du es wirklich löschen?" :
            "Möchtest du dieses Profil wirklich löschen?"
        
        let alert = UIAlertController(
            title: "Profil löschen",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Abbrechen", style: .cancel))
        alert.addAction(UIAlertAction(title: "Löschen", style: .destructive) { _ in
            // Remove the profile
            profileManager.deleteProfile(at: index)
        })
        
        if let presenter = rootViewController.presentedViewController {
            presenter.present(alert, animated: true)
        } else {
            rootViewController.present(alert, animated: true)
        }
    }
}

struct ProfileCellBase: View {
    let name: String
    let icon: String
    let appsBlocked: Int?
    let categoriesBlocked: Int?
    let isSelected: Bool
    var isDashed: Bool = false
    var hasDivider: Bool = true

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
            if hasDivider {
                Divider().padding(2)
            }
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            
            if let apps = appsBlocked, let categories = categoriesBlocked {
                Text("A: \(apps) | C: \(categories)")
                    .font(.system(size: 10))
            }
        }
        .frame(width: 90, height: 90)
        .padding(2)
        .background(isSelected ? Color.blue.opacity(0.3) : Color.secondary.opacity(0.2))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? Color.blue : (isDashed ? Color.secondary : Color.clear),
                    style: StrokeStyle(lineWidth: 2, dash: isDashed ? [5] : [])
                )
        )
    }
}

struct ProfileCell: View {
    let profile: Profile
    let isSelected: Bool

    var body: some View {
        ProfileCellBase(
            name: profile.name,
            icon: profile.icon,
            appsBlocked: profile.appTokens.count,
            categoriesBlocked: profile.categoryTokens.count,
            isSelected: isSelected
        )
    }
}

struct ProfilePicker_Previews: PreviewProvider {
    static var previews: some View {
        ProfilesPicker(profileManager: ProfileManager())
    }
}
