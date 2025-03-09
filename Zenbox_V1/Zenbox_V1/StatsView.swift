//
//  StatsView.swift
//  Zenbox_V1
//
//  Created by Assistant on 23/08/2024.
//

import SwiftUI

struct StatsView: View {
    @EnvironmentObject var viewModel: TimerViewModel
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    
    // Add these properties for the weekly overview
    @State private var weekDays: [String] = []
    @State private var sessionsPerDay: [String: TimeInterval] = [:]
    @State private var currentStreak: Int = 0
    @State private var monthlySessionsGoal: Int = 30
    @State private var monthlySessionsCompleted: Int = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    StreakSectionView(viewModel: viewModel, settingsViewModel: settingsViewModel)
                    MilestonesSectionView(viewModel: viewModel, settingsViewModel: settingsViewModel)
                    StatisticsSectionView(viewModel: viewModel, settingsViewModel: settingsViewModel)
                    WeeklyOverviewSectionView(
                        weekDays: weekDays,
                        sessionsPerDay: sessionsPerDay,
                        settingsViewModel: settingsViewModel
                    )
                    MonthlyGoalsSectionView(
                        viewModel: viewModel,
                        monthlySessionsCompleted: monthlySessionsCompleted,
                        settingsViewModel: settingsViewModel
                    )
                    LastSessionsSectionView(viewModel: viewModel, settingsViewModel: settingsViewModel)
                }
                .padding()
                .padding(.bottom, 100)
            }
            .background(settingsViewModel.isDarkMode ? Color.zenboxDarkBackground : Color(UIColor.systemGroupedBackground))
            .edgesIgnoringSafeArea(.bottom)
            .navigationTitle("Meine Statistiken")
            .navigationBarTitleDisplayMode(.large)
            .accentColor(settingsViewModel.isDarkMode ? .zenboxDarkAccent : .zenboxBlue)
        }
        .background(settingsViewModel.isDarkMode ? Color.zenboxDarkBackground : Color(UIColor.systemGroupedBackground))
        .preferredColorScheme(settingsViewModel.isDarkMode ? .dark : .light)
        .onAppear {
            calculateWeeklyStats()
            currentStreak = viewModel.currentStreak
            calculateMonthlyStats()
        }
    }
    
    // Calculate weekly statistics
    private func calculateWeeklyStats() {
        // Get the last 7 days
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var days: [String] = []
        var sessionsMap: [String: TimeInterval] = [:]
        
        // Create array of the last 7 days (starting with today)
        for dayOffset in 0..<7 {
            let day = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            let dayString = formatDayOfWeek(day)
            days.insert(dayString, at: 0) // Insert at beginning to get chronological order
            sessionsMap[dayString] = 0
        }
        
        // Calculate total session time for each day
        for session in viewModel.sessions {
            let sessionDay = calendar.startOfDay(for: session.date)
            if sessionDay >= calendar.date(byAdding: .day, value: -6, to: today)! {
                let dayString = formatDayOfWeek(sessionDay)
                sessionsMap[dayString, default: 0] += session.duration
            }
        }
        
        self.weekDays = days
        self.sessionsPerDay = sessionsMap
    }
    
    // Calculate monthly statistics
    private func calculateMonthlyStats() {
        let calendar = Calendar.current
        let today = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        
        // Count sessions in current month
        let sessionsThisMonth = viewModel.sessions.filter { 
            calendar.isDate($0.date, inSameDayAs: today) || 
            ($0.date >= startOfMonth && $0.date < today)
        }
        
        monthlySessionsCompleted = sessionsThisMonth.count
    }
    
    // Helper function to format day of week
    private func formatDayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E" // Short day name (Mon, Tue, etc.)
        return formatter.string(from: date)
    }
    
    // Helper function to format day abbreviation in German
    private func formatDayShort(_ day: String) -> String {
        // Convert English day abbreviation to German
        switch day {
        case "Mon": return "Mo"
        case "Tue": return "Di"
        case "Wed": return "Mi"
        case "Thu": return "Do"
        case "Fri": return "Fr"
        case "Sat": return "Sa"
        case "Sun": return "So"
        default: return day
        }
    }
    
    // Helper function to get bar height based on session time
    private func getBarHeight(_ sessionTime: TimeInterval) -> CGFloat {
        let maxHeight: CGFloat = 150 // Maximum bar height
        let maxTime: TimeInterval = 3600 * 3 // 3 hours as reference maximum
        
        // Calculate height proportionally, with a minimum height if there's any session
        let height = sessionTime > 0 ? max(20, min(maxHeight, CGFloat(sessionTime / maxTime) * maxHeight)) : 0
        return height
    }
    
    // Helper function to format total time
    private func formatTotalTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, 0)
        } else {
            return String(format: "%02d:%02d", minutes, 0)
        }
    }
    
    // Helper function to format time
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // Helper function to format date
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }
    
    // Helper function to format time
    private func formatTime(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    // Add this helper function for shorter time format
    private func formatTimeShort(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        return "\(minutes)"
    }
}

// MARK: - Section Views
struct StreakSectionView: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        HStack {
            Image(systemName: viewModel.isStreakActive ? "flame.fill" : "flame")
                .foregroundColor(viewModel.isStreakActive ? .orange : .gray)
                .font(.system(size: 40))
            
            VStack(alignment: .leading) {
                Text("\(viewModel.currentStreak) Tage Streak")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkText : .primary)
                
                Text("Seit \(viewModel.currentStreak) Tagen")
                    .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(settingsViewModel.isDarkMode ? Color.zenboxDarkCardBackground : Color(UIColor.systemBackground))
                .shadow(
                    color: settingsViewModel.isDarkMode ? .black.opacity(0.3) : .black.opacity(0.1),
                    radius: settingsViewModel.isDarkMode ? 20 : 10,
                    x: 0,
                    y: settingsViewModel.isDarkMode ? 8 : 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(settingsViewModel.isDarkMode ? Color.white.opacity(0.07) : Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

struct MilestonesSectionView: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        Section(header: Text("Meilensteine")
            .font(.title2)
            .fontWeight(.medium)
            .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkText : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)) {
            HStack(spacing: 20) {
                MilestoneView(number: 1, days: 3, isReached: viewModel.currentStreak >= 3)
                MilestoneView(number: 2, days: 7, isReached: viewModel.currentStreak >= 7)
                MilestoneView(number: 3, days: 14, isReached: viewModel.currentStreak >= 14)
                MilestoneView(number: 4, days: 30, isReached: viewModel.currentStreak >= 30)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(settingsViewModel.isDarkMode ? Color.zenboxDarkCardBackground : Color(UIColor.systemBackground))
                    .shadow(
                        color: settingsViewModel.isDarkMode ? .black.opacity(0.3) : .black.opacity(0.1),
                        radius: settingsViewModel.isDarkMode ? 20 : 10,
                        x: 0,
                        y: settingsViewModel.isDarkMode ? 8 : 4
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(settingsViewModel.isDarkMode ? Color.white.opacity(0.07) : Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct StatisticsSectionView: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        Section(header: Text("Session Statistiken")
            .font(.title2)
            .fontWeight(.medium)
            .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkText : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)) {
            HStack(spacing: 20) {
                StatItemView(
                    icon: "number",
                    value: "\(viewModel.sessions.count)",
                    label: "Gesamt",
                    iconColor: .zenboxDarkAccent
                )
                
                StatItemView(
                    icon: "clock",
                    value: formatTotalTime(viewModel.sessions.reduce(0) { $0 + $1.duration }),
                    label: "Zeit",
                    iconColor: .zenboxDarkAccent
                )
                
                StatItemView(
                    icon: "arrow.counterclockwise",
                    value: formatTime(viewModel.lastSessionTime),
                    label: "Letzte",
                    iconColor: .red
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(settingsViewModel.isDarkMode ? Color.zenboxDarkCardBackground : Color(UIColor.systemBackground))
                    .shadow(
                        color: settingsViewModel.isDarkMode ? .black.opacity(0.3) : .black.opacity(0.1),
                        radius: settingsViewModel.isDarkMode ? 20 : 10,
                        x: 0,
                        y: settingsViewModel.isDarkMode ? 8 : 4
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(settingsViewModel.isDarkMode ? Color.white.opacity(0.07) : Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private func formatTotalTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, 0)
        } else {
            return String(format: "%02d:%02d", minutes, 0)
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

struct WeeklyOverviewSectionView: View {
    let weekDays: [String]
    let sessionsPerDay: [String: TimeInterval]
    @ObservedObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        Section(header: Text("Wochenübersicht")
            .font(.title2)
            .fontWeight(.medium)
            .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkText : .primary)) {
            VStack(spacing: 16) {
                // Total time this week
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Diese Woche")
                            .font(.subheadline)
                            .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .secondary)
                        Text(formatTotalWeekTime())
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkText : .primary)
                    }
                    Spacer()
                }
                
                // Graph
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(weekDays, id: \.self) { day in
                    VStack(spacing: 8) {
                            if let sessionTime = sessionsPerDay[day], sessionTime > 0 {
                                // Time label
                                Text(formatTimeShort(sessionTime))
                                    .font(.caption2)
                                    .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .secondary)
                                
                                // Bar
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(settingsViewModel.isDarkMode ? Color.zenboxDarkAccent : Color.zenboxBlue)
                                    .frame(height: getBarHeight(sessionTime))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(
                                                (settingsViewModel.isDarkMode ? Color.zenboxDarkAccent : Color.zenboxBlue)
                                                    .opacity(0.3),
                                                lineWidth: 1
                                            )
                                    )
                            } else {
                                // Empty state
                                Text("-")
                                    .font(.caption2)
                                    .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .secondary)
                                
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.clear)
                                    .frame(height: 4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(
                                                (settingsViewModel.isDarkMode ? Color.zenboxDarkSecondaryText : Color.secondary)
                                                    .opacity(0.2),
                                                lineWidth: 1
                                            )
                                    )
                            }
                        
                        // Day label
                            Text(formatDayShort(day))
                                .font(.caption)
                                .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .secondary)
                                .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .padding(.horizontal, 2)
                    }
                }
                
                // Legend
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(settingsViewModel.isDarkMode ? Color.zenboxDarkAccent : Color.zenboxBlue)
                            .frame(width: 8, height: 8)
                        Text("Fokuszeit")
                            .font(.caption)
                            .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .secondary)
                    }
                    
                    Text("•")
                        .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .secondary)
                    
                    Text(getAverageTimePerDay())
                        .font(.caption)
                        .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(settingsViewModel.isDarkMode ? Color.zenboxDarkCardBackground : Color(UIColor.systemBackground))
                    .shadow(
                        color: settingsViewModel.isDarkMode ? .black.opacity(0.3) : .black.opacity(0.1),
                        radius: settingsViewModel.isDarkMode ? 20 : 10,
                        x: 0,
                        y: settingsViewModel.isDarkMode ? 8 : 4
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(settingsViewModel.isDarkMode ? Color.white.opacity(0.07) : Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private func getBarHeight(_ sessionTime: TimeInterval) -> CGFloat {
        let maxHeight: CGFloat = 150
        let maxTime: TimeInterval = 3600 * 3 // 3 hours as reference maximum
        let height = sessionTime > 0 ? max(20, min(maxHeight, CGFloat(sessionTime / maxTime) * maxHeight)) : 0
        return height
    }
    
    private func formatDayShort(_ day: String) -> String {
        switch day {
        case "Mon": return "Mo"
        case "Tue": return "Di"
        case "Wed": return "Mi"
        case "Thu": return "Do"
        case "Fri": return "Fr"
        case "Sat": return "Sa"
        case "Sun": return "So"
        default: return day
        }
    }
    
    private func formatTimeShort(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        if minutes >= 60 {
            let hours = minutes / 60
            return "\(hours)h"
        }
        return "\(minutes)m"
    }
    
    private func formatTotalWeekTime() -> String {
        let totalTime = sessionsPerDay.values.reduce(0, +)
        let hours = Int(totalTime) / 3600
        let minutes = Int(totalTime) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m Fokuszeit"
        } else {
            return "\(minutes)m Fokuszeit"
        }
    }
    
    private func getAverageTimePerDay() -> String {
        let totalTime = sessionsPerDay.values.reduce(0, +)
        let daysWithSessions = sessionsPerDay.values.filter { $0 > 0 }.count
        
        if daysWithSessions == 0 {
            return "Ø 0m pro Tag"
        }
        
        let averageMinutes = Int(totalTime / TimeInterval(daysWithSessions)) / 60
        if averageMinutes >= 60 {
            let hours = averageMinutes / 60
            let minutes = averageMinutes % 60
            return "Ø \(hours)h \(minutes)m pro Tag"
        }
        return "Ø \(averageMinutes)m pro Tag"
    }
}

struct MonthlyGoalsSectionView: View {
    @ObservedObject var viewModel: TimerViewModel
    let monthlySessionsCompleted: Int
    @ObservedObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        Section(header: Text("Monatsziele")
            .font(.title2)
            .fontWeight(.medium)
            .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkText : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                    Text("30 Sessions")
                            .font(.headline)
                            .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkText : .primary)
                        Spacer()
                        Text("\(monthlySessionsCompleted)/30")
                            .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .secondary)
                    }
                    
                    ProgressBar(value: Float(monthlySessionsCompleted) / 30.0, color: settingsViewModel.isDarkMode ? .zenboxDarkAccent : .zenboxBlue)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                    Text("7-Tage Streak")
                            .font(.headline)
                            .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkText : .primary)
                        Spacer()
                        Text("\(min(viewModel.currentStreak, 7))/7")
                            .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .secondary)
                    }
                    
                    ProgressBar(value: Float(min(viewModel.currentStreak, 7)) / 7.0, color: .orange)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(settingsViewModel.isDarkMode ? Color.zenboxDarkCardBackground : Color(UIColor.systemBackground))
                    .shadow(
                        color: settingsViewModel.isDarkMode ? .black.opacity(0.3) : .black.opacity(0.1),
                        radius: settingsViewModel.isDarkMode ? 20 : 10,
                        x: 0,
                        y: settingsViewModel.isDarkMode ? 8 : 4
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(settingsViewModel.isDarkMode ? Color.white.opacity(0.07) : Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct LastSessionsSectionView: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    @State private var showAllSessions = false
    
    var body: some View {
        Section(header: HStack {
            Text("Letzte Sessions")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkText : .primary)
            
            Spacer()
        }) {
            VStack(spacing: 12) {
                if viewModel.sessions.isEmpty {
                    Text("Keine Sessions vorhanden")
                        .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .secondary)
                        .padding()
                } else {
                    ForEach(Array(viewModel.sessions.reversed().prefix(5)), id: \.id) { session in
                        SessionRowView(session: session, settingsViewModel: settingsViewModel)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(settingsViewModel.isDarkMode ? Color.zenboxDarkCardBackground : Color(UIColor.systemBackground))
                    .shadow(
                        color: settingsViewModel.isDarkMode ? .black.opacity(0.3) : .black.opacity(0.1),
                        radius: settingsViewModel.isDarkMode ? 20 : 10,
                        x: 0,
                        y: settingsViewModel.isDarkMode ? 8 : 4
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(settingsViewModel.isDarkMode ? Color.white.opacity(0.07) : Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct SessionRowView: View {
    let session: Session
    @ObservedObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(settingsViewModel.isDarkMode ? 
                          Color.zenboxDarkAccent.opacity(0.2) : 
                          Color.zenboxBlue.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                VStack(spacing: 2) {
                    Text(formatTimeShort(session.duration))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkAccent : .zenboxBlue)
                    Text("Min")
                        .font(.system(size: 11))
                        .foregroundColor(settingsViewModel.isDarkMode ? 
                                       .zenboxDarkAccent.opacity(0.7) : 
                                       .zenboxBlue.opacity(0.7))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDate(session.date))
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkText : .primary)
                
                HStack(spacing: 6) {
                    Image(systemName: session.profileIcon)
                        .font(.system(size: 12))
                        .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .secondary)
                    Text(session.profileName)
                        .font(.system(size: 13))
                        .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .secondary)
                }
            }
            
            Spacer()
            
            Text(formatTime(from: session.date))
                .font(.system(size: 15))
                .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(settingsViewModel.isDarkMode ? 
                      Color.zenboxDarkCardBackground : 
                      Color(UIColor.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(settingsViewModel.isDarkMode ? Color.white.opacity(0.07) : Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func formatTimeShort(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        return "\(minutes)"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }
    
    private func formatTime(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// Milestone view component
struct MilestoneView: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    let number: Int
    let days: Int
    let isReached: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isReached ? 
                          (settingsViewModel.isDarkMode ? Color.green.opacity(0.3) : Color.green.opacity(0.2)) : 
                          (settingsViewModel.isDarkMode ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2)))
                    .frame(width: 40, height: 40)
                
                Text("\(number)")
                    .fontWeight(.bold)
                    .foregroundColor(isReached ? 
                                   (settingsViewModel.isDarkMode ? .green : .green) : 
                                   (settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .gray))
            }
            
            Text("\(days) Tage")
                .font(.caption)
                .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// Stat item component
struct StatItemView: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    let icon: String
    let value: String
    let label: String
    let iconColor: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(settingsViewModel.isDarkMode ? 
                          iconColor.opacity(0.3) : 
                          iconColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
            Image(systemName: icon)
                    .foregroundColor(settingsViewModel.isDarkMode ? 
                                   iconColor : 
                                   iconColor)
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkText : .primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(settingsViewModel.isDarkMode ? .zenboxDarkSecondaryText : .secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// Progress bar component
struct ProgressBar: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    var value: Float
    var color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(width: geometry.size.width, height: 8)
                    .opacity(settingsViewModel.isDarkMode ? 0.3 : 0.2)
                    .foregroundColor(color)
                    .cornerRadius(4)
                
                Rectangle()
                    .frame(width: min(CGFloat(self.value) * geometry.size.width, geometry.size.width), height: 8)
                    .foregroundColor(color)
                    .cornerRadius(4)
            }
        }
        .frame(height: 8)
    }
}

struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        StatsView()
            .environmentObject(TimerViewModel())
            .environmentObject(SettingsViewModel())
    }
} 
