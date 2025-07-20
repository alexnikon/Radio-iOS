import UserNotifications
import Foundation

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                self.scheduleWeeklyNotification()
            }
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }
    
    func scheduleWeeklyNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Radio-T"
        content.body = "Трансляция начнется через 15 минут"
        content.sound = .default
        
        // Создаем компоненты даты для субботы 22:45 МСК
        var dateComponents = DateComponents()
        dateComponents.weekday = 7 // Суббота (1 = воскресенье, 7 = суббота)
        dateComponents.hour = 22
        dateComponents.minute = 45
        dateComponents.timeZone = TimeZone(identifier: "Europe/Moscow")
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "radio-t-live", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    // Обработка уведомлений когда приложение активно
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
} 