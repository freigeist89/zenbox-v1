import Foundation

struct Streak: Codable {
    var count: Int
    var lastUsedDate: Date?
    
    // Initialize with default values
    init(count: Int = 0, lastUsedDate: Date? = nil) {
        self.count = count
        self.lastUsedDate = lastUsedDate
    }
}
