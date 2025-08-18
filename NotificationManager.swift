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
        // Первое напоминание за 30 минут до начала
        let content30min = UNMutableNotificationContent()
        content30min.title = "Radio-T"
        content30min.body = "Прямой эфир начнется через 30 минут!"
        content30min.sound = .default
        
        // Создаем компоненты даты для субботы 22:30 МСК (за 30 минут)
        var dateComponents30min = DateComponents()
        dateComponents30min.weekday = 7 // Суббота (1 = воскресенье, 7 = суббота)
        dateComponents30min.hour = 22
        dateComponents30min.minute = 30
        dateComponents30min.timeZone = TimeZone(identifier: "Europe/Moscow")
        
        let trigger30min = UNCalendarNotificationTrigger(dateMatching: dateComponents30min, repeats: true)
        let request30min = UNNotificationRequest(identifier: "radio-t-live-30min", content: content30min, trigger: trigger30min)
        
        // Второе напоминание точно в момент начала эфира
        let contentStart = UNMutableNotificationContent()
        contentStart.title = "Radio-T"
        contentStart.body = "Прямой эфир начался! Слушайте прямо сейчас!"
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
        UNUserNotificationCenter.current().add(request30min) { error in
            if let error = error {
                print("Error scheduling 30min notification: \(error)")
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