import SwiftUI

// Our category model
struct Category: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
}

struct CategoryListView: View {
    @State private var categories = [
        Category(name: "Social Media Apps", description: "Instagram ist gesperrt", icon: "bubble.left.fill"),
        Category(name: "Work", description: "Social Media und Entertainment Apps sind gesperrt", icon: "briefcase.fill"),
        Category(name: "Fitness Studio", description: "Nur Audio-Apps sind erlaubt.", icon: "heart.fill"),
        Category(name: "Sleep", description: "Social Media ist gesperrt.", icon: "moon.fill"),
        Category(name: "Running", description: "Nur Audio-Apps sind erlaubt.", icon: "waveform.path.ecg")
    ]
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // List of categories
                    List {
                        ForEach(categories) { category in
                            CategoryRow(category: category)
                                .listRowInsets(EdgeInsets())
                                .background(Color(UIColor.systemBackground))
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        if let index = categories.firstIndex(where: { $0.id == category.id }) {
                                            categories.remove(at: index)
                                        }
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                    
                                    Button {
                                        // More action
                                    } label: {
                                        Label("Mehr", systemImage: "ellipsis")
                                    }
                                    .tint(.gray)
                                }
                        }
                    }
                    .listStyle(PlainListStyle())
                    
                    
                    .background(Color(UIColor.systemBackground))
                }
                
                VStack {
                    Spacer()
                    Button(action: {}) {
                        ZStack {
                            Circle()
                                .fill(Color.zenboxBlue)
                                .frame(width: 50, height: 50)

                            Image(systemName: "plus")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Modus")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.zenboxBlue)
                            .font(.system(size: 18))
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(15)
                    }
                }
            }
        }
    }
}

struct CategoryRow: View {
    let category: Category
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(.zenboxBlue)
                
                Text(category.name)
                    .font(.headline)
                    .foregroundColor(.zenboxBlue)
                
                Spacer()
            }
            
            Text(category.description)
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(2)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
    }
}

// Preview
struct CategoryListView_Previews: PreviewProvider {
    static var previews: some View {
        CategoryListView()
    }
}
