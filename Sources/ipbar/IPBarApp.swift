import SwiftUI

@main
struct IPBarApp: App {
    @State private var model = IPModel()

    var body: some Scene {
        MenuBarExtra {
            if let ip = model.ip {
                Button("Copy \(ip)") { model.copyIP() }
                    .keyboardShortcut("c")
                if let country = model.countryName {
                    Text(country)
                }
            } else {
                Text(model.failed ? "Can't reach the IP lookup service" : "Looking up…")
            }
            if let checked = model.lastChecked {
                Text("Checked \(checked.formatted(date: .omitted, time: .shortened))\(model.failed ? " (now offline)" : "")")
            }
            Divider()
            Button("Refresh") { model.refresh() }
                .keyboardShortcut("r")
            Button("Quit ipbar") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Text(model.label)
        }
    }
}
