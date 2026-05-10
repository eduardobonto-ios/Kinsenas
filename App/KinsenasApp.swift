import SwiftUI

@main
struct KinsenasApp: App {
    
    @State private var isLocked = false
    @StateObject private var purchaseManager = PurchaseManager()
    
    init() {
        // 🔔 Setup notifications (only once)
        if let install = KeychainHelper.getDouble(key: "kinsenas_install_date") {
            let installDate = Date(timeIntervalSince1970: install)
            TrialNotificationManager.requestPermission()
            TrialNotificationManager.schedule(installDate: installDate)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                
                if isLocked {
                    PaywallView()
                        .background(.ultraThinMaterial)
                }
            }
            .environmentObject(purchaseManager) // 🔥 REQUIRED
            
            // ✅ Load purchase state
            .task {
                await purchaseManager.loadPurchaseStatus()
                
                let trial = TrialManager.shared
                
                if !purchaseManager.isPurchased &&
                    (trial.checkTimeTampering() || trial.isExpired()) {
                    isLocked = true
                }
            }
            
            // 🔄 Re-check when app returns (anti-cheat)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                
                let trial = TrialManager.shared
                
                if !purchaseManager.isPurchased &&
                    (trial.checkTimeTampering() || trial.isExpired()) {
                    isLocked = true
                }
            }
                
            .onChange(of: purchaseManager.isPurchased) {
                if purchaseManager.isPurchased {
                    isLocked = false
                }
            }
        }
    }
}
