import Foundation
import UserNotifications

class NotificationHelper {
    
    static func createSessionCompletedContent(duration: TimeInterval, useEmoji: Bool, useSound: Bool) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        
        // Always show emojis in notifications
        content.title = "🎯 Ziel erreicht! 🎉"
        content.body = "🚀 Großartig! Du hast deine geplante Session von \(formatTime(duration)) gemeistert. ✅ Alle Apps sind jetzt wieder entsperrt. 💪 Sei stolz auf dich!"
        
        // Always use sound for goal completion to make it more noticeable
        content.sound = useSound ? .defaultCritical : .default
        
        // Set notification category for special handling
        content.categoryIdentifier = "SESSION_COMPLETED"
        
        // Add badge
        content.badge = 1
        
        return content
    }
    
    // Helper function to format time
    private static func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        
        if hours > 0 {
            return "\(hours) Std \(minutes) Min"
        } else {
            return "\(minutes) Min"
        }
    }
} 