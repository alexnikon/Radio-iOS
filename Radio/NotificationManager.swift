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
        // Первое уведомление за 15 минут до начала
        let content15min = UNMutableNotificationContent()
        content15min.title = "Radio-T"
        content15min.body = "Трансляция начнется через 15 минут"
        content15min.sound = .default
        
        // Создаем компоненты даты для субботы 22:45 МСК (за 15 минут)
        var dateComponents15min = DateComponents()
        dateComponents15min.weekday = 7 // Суббота (1 = воскресенье, 7 = суббота)
        dateComponents15min.hour = 22
        dateComponents15min.minute = 45
        dateComponents15min.timeZone = TimeZone(identifier: "Europe/Moscow")
        
        let trigger15min = UNCalendarNotificationTrigger(dateMatching: dateComponents15min, repeats: true)
        let request15min = UNNotificationRequest(identifier: "radio-t-live-15min", content: content15min, trigger: trigger15min)
        
        // Второе уведомление точно в момент начала эфира
        let contentStart = UNMutableNotificationContent()
        contentStart.title = "Radio-T"
        contentStart.body = "Трансляция началась"
        contentStart.sound = .default
        
        // Создаем компоненты даты для субботы 23:00 МСК
        var dateComponentsStart = DateComponents()
        dateComponentsStart.weekday = 7 // Суббота (1 = воскресенье, 7 = суббота)
        dateComponentsStart.hour = 23
        dateComponentsStart.minute = 0
        dateComponentsStart.timeZone = TimeZone(identifier: "Europe/Moscow")
        
        let triggerStart = UNCalendarNotificationTrigger(dateMatching: dateComponentsStart, repeats: true)
        let requestStart = UNNotificationRequest(identifier: "radio-t-live-start", content: contentStart, trigger: triggerStart)
        
        // Планируем оба уведомления
        UNUserNotificationCenter.current().add(request15min) { error in
            if let error = error {
                print("Error scheduling 15min notification: \(error)")
            }
        }
        
        UNUserNotificationCenter.current().add(requestStart) { error in
            if let error = error {
                print("Error scheduling start notification: \(error)")
            }
        }
    }
    
    // Обработка уведомлений когда приложение активно
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
} 