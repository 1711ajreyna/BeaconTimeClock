import SwiftUI

/// Reusable Container Supply / BeaconTimeClock branding
struct BrandHeaderView: View {
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            
            VStack(
                alignment: .leading,
                spacing: 2
            ){
                Text("BeaconTimeClock")
                    .font(.title2.bold())
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}
