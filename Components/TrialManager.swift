import Foundation

final class TrialManager {
    
    static let shared = TrialManager()
    
    private let installKey = "kinsenas_install_date"
    private let lastOpenKey = "kinsenas_last_open"
    
    private let trialDays = 14
    
    private init() {
        setupInstallDateIfNeeded()
    }
    
    private func setupInstallDateIfNeeded() {
        if KeychainHelper.getDouble(key: installKey) == nil {
            let now = Date().timeIntervalSince1970
            KeychainHelper.set(key: installKey, value: now)
        }
    }
    
    // MARK: - Core Checks
    
    func isExpired() -> Bool {
        let now = Date()
        let install = Date(timeIntervalSince1970: installTimestamp())
        
        let days = Calendar.current.dateComponents([.day], from: install, to: now).day ?? 0
        
        return days >= trialDays
    }
    
    func daysRemaining() -> Int {
        let now = Date()
        let install = Date(timeIntervalSince1970: installTimestamp())
        
        let used = Calendar.current.dateComponents([.day], from: install, to: now).day ?? 0
        
        return max(0, trialDays - used)
    }
    
    func checkTimeTampering() -> Bool {
        let now = Date().timeIntervalSince1970
        let lastOpen = KeychainHelper.getDouble(key: lastOpenKey) ?? now
        
        // 🚨 If time moved backwards
        if now < lastOpen {
            return true
        }
        
        KeychainHelper.set(key: lastOpenKey, value: now)
        return false
    }
    
    private func installTimestamp() -> Double {
        return KeychainHelper.getDouble(key: installKey) ?? Date().timeIntervalSince1970
    }
}
