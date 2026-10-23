import SwiftUI
import Playgrounds

struct ContentView: View {
    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        Text("Hello, world!")
            .padding()
        .enableInjection()
    }
}

#Preview {
    ContentView()
}

#Playground {
    _ = 1 + 2
}
