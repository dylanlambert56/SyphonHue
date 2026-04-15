import SwiftUI

@main
struct SyphonHueApp: App {
    var body: some Scene {
        WindowGroup("SyphonHue") {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About SyphonHue") {
                    AboutPanel.show()
                }
            }
        }
    }
}
