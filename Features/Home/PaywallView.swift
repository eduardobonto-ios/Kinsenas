import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var purchaseManager: PurchaseManager
    
    var body: some View {
        VStack(spacing: 20) {
            
            Spacer()
            
            Text("Trial Expired")
                .font(.largeTitle)
                .bold()
            
            Text("Unlock Kinsenas for ₱99 lifetime")
                .foregroundColor(.gray)
            
            // 🔥 Unlock Button
            Button("Unlock for ₱99") {
                Task {
                    await purchaseManager.buy()
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal, 40)
            
            // 🔁 Restore Button
            Button("Restore Purchase") {
                Task {
                    await purchaseManager.restore()
                }
            }
            .font(.footnote)
            .padding(.top, 10)
            
            Spacer()
        }
    }
}
