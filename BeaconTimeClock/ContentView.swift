// FILE PURPOSE: Template SwiftUI view; verify whether BeaconTimeClockApp actually launches it before editing.
import SwiftUI

// This type groups related state and behavior under a clear responsibility.
struct ContentView: View {
    // The SwiftUI body describes the visible screen from the current state.
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
