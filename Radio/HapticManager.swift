import UIKit

class HapticManager {
    static let shared = HapticManager()
    
    // Кэшируем генераторы для оптимизации
    private lazy var lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private lazy var mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private lazy var heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private lazy var notificationGenerator = UINotificationFeedbackGenerator()
    
    private init() {
        // Подготавливаем генераторы заранее для лучшей производительности
        prepareGenerators()
        
        // Слушаем изменения состояния приложения для управления ресурсами
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // Проверка активности приложения для экономии ресурсов
    private var isAppActive: Bool {
        let state = UIApplication.shared.applicationState
        return state == .active
    }
    
    // Подготовка генераторов для лучшей производительности
    private func prepareGenerators() {
        guard isAppActive else { return }
        
        lightImpactGenerator.prepare()
        mediumImpactGenerator.prepare()
        heavyImpactGenerator.prepare()
        notificationGenerator.prepare()
    }
    
    @objc private func applicationDidBecomeActive() {
        prepareGenerators()
    }
    
    @objc private func applicationWillResignActive() {
        // Очищаем ресурсы при деактивации приложения
        // Генераторы будут пересозданы при необходимости
    }
    
    // Легкая тактильная обратная связь для обычных нажатий
    func lightImpact() {
        guard isAppActive else { return }
        lightImpactGenerator.impactOccurred()
    }
    
    // Средняя тактильная обратная связь для более важных действий
    func mediumImpact() {
        guard isAppActive else { return }
        mediumImpactGenerator.impactOccurred()
    }
    
    // Сильная тактильная обратная связь для критических действий
    func heavyImpact() {
        guard isAppActive else { return }
        heavyImpactGenerator.impactOccurred()
    }
    
    // Успешная тактильная обратная связь
    func success() {
        guard isAppActive else { return }
        notificationGenerator.notificationOccurred(.success)
    }
    
    // Ошибка тактильная обратная связь
    func error() {
        guard isAppActive else { return }
        notificationGenerator.notificationOccurred(.error)
    }
    
    // Предупреждение тактильная обратная связь
    func warning() {
        guard isAppActive else { return }
        notificationGenerator.notificationOccurred(.warning)
    }
    
    // Тактильная обратная связь для воспроизведения
    func playFeedback() {
        mediumImpact()
    }
    
    // Тактильная обратная связь для остановки
    func stopFeedback() {
        heavyImpact()
    }
}
