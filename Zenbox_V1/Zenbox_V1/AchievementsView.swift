import SwiftUI

struct AchievementsView: View {
    var body: some View {
        VStack {
            Text("Erfolge")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.zenboxTitleBlue)
                .padding(.top)
            
            Text("Hier werden bald deine Erfolge angezeigt.")
                .padding()
            
            Spacer()
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

struct AchievementsView_Previews: PreviewProvider {
    static var previews: some View {
        AchievementsView()
    }
} 