import SwiftUI

@main
struct SyphonHueApp: App {
    var body: some Scene {
        WindowGroup("SyphonHue") {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
    }
}
