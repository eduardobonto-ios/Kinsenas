import UserNotifications

final class TrialNotificationManager {
    
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    static func schedule(installDate: Date) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        let scheduleDays = [
            (7, "7 days left in your Kinsenas trial"),
            (11, "Only 3 days left! Unlock Kinsenas now."),
            (13, "Last day! Don’t lose access.")
        ]
        
        for (day, message) in scheduleDays {
            guard let triggerDate = Calendar.current.date(byAdding: .day, value: day, to: installDate) else { continue }
            
            var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            components.hour = 9 // send at 9 AM
            
            let content = UNMutableNotificationContent()
            content.title = "Kinsenas"
            content.body = message
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            
            let request = UNNotificationRequest(
                identifier: "trial_\(day)",
                content: content,
                trigger: trigger
            )
            
            center.add(request)
        }
    }
}
