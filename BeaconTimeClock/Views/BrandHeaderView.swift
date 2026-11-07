// FILE PURPOSE: Reusable Container Supply / BeaconTimeClock brand header.
import SwiftUI

/// Reusable company wordmark and BeaconTimeClock capstone emblem.
/// Replace BrandLogo in Assets.xcassets with an approved corporate asset later.
// This type groups related state and behavior under a clear responsibility.
struct BrandHeaderView: View {
    let subtitle: String

    // The SwiftUI body describes the visible screen from the current state.
    var body: some View {
        HStack(spacing: 14) {
            // This asset must exist in Assets.xcassets; image names are case-sensitive.
            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .accessibilityLabel("BeaconTimeClock emblem")

            VStack(alignment: .leading, spacing: 5) {
                Text("CONTAINER SUPPLY")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(CSCTheme.steel)

                Text(AppLocalization.text(subtitle))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(CSCTheme.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    BrandHeaderView(subtitle: "Employee Time Clock")
        .padding()
        .background(CSCTheme.canvas)
}
