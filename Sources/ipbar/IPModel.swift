import AppKit
import Foundation
import Network
import Observation
import SystemConfiguration

/// Looks up the public IP address and keeps it current.
///
/// The network monitor is only ever a *trigger* to look again, never a gate:
/// the app always attempts the lookup and says "offline" only when the lookup
/// itself fails. (Display My IP, which this replaces, trusted its own offline
/// check and got stuck on "Resolving…" while the network was fine.)
@MainActor
@Observable
final class IPModel {
    /// This Mac's address on the local network (primary interface).
    private(set) var localIP: String?
    private(set) var localInterface: String?
    /// The public address the internet sees.
    private(set) var ip: String?
    private(set) var countryCode: String?
    private(set) var lastChecked: Date?
    private(set) var failed = false
    private(set) var busy = false

    private let refreshInterval: TimeInterval = 5 * 60
    private let retryInterval: TimeInterval = 30
    private var timer: Timer?
    private var pathMonitor: NWPathMonitor?
    private var pathDebounce: Task<Void, Never>?

    init() {
        startPathMonitor()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshSoon(after: 3) }
        }
        refresh()
    }

    /// Menu bar text: the local address, or a status word.
    var label: String { localIP ?? "No network" }

    /// Menu text for the public address: flag plus address, or a status word.
    var externalLabel: String {
        if let ip {
            let flag = countryCode.map(Self.flag) ?? "🌐"
            return failed ? "\(flag) \(ip)?" : "\(flag) \(ip)"
        }
        return failed ? "Offline" : "Looking up…"
    }

    var countryName: String? {
        countryCode.flatMap { Locale.current.localizedString(forRegionCode: $0) }
    }

    func refresh() {
        updateLocalIP()
        guard !busy else { return }
        busy = true
        Task {
            let result = await Self.lookUp()
            busy = false
            if let result {
                // Keep the old flag if the fallback lookup returned no country
                // but the address did not change.
                if result.country != nil || result.ip != ip { countryCode = result.country }
                ip = result.ip
                failed = false
                lastChecked = Date()
                schedule(after: refreshInterval)
            } else {
                failed = true
                schedule(after: retryInterval)
            }
        }
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: - Local address

    /// Reads the primary interface's IPv4 address. Purely local, no network request,
    /// so it is updated immediately on every network change.
    func updateLocalIP() {
        let (address, interface) = Self.primaryIPv4()
        localIP = address
        localInterface = interface
    }

    private nonisolated static func primaryIPv4() -> (String?, String?) {
        guard let store = SCDynamicStoreCreate(nil, "ipbar" as CFString, nil, nil),
              let global = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
              let interface = global["PrimaryInterface"] as? String,
              let state = SCDynamicStoreCopyValue(store, "State:/Network/Interface/\(interface)/IPv4" as CFString) as? [String: Any],
              let addresses = state["Addresses"] as? [String],
              let first = addresses.first
        else { return (nil, nil) }
        return (first, interface)
    }

    // MARK: - Scheduling

    private func schedule(after seconds: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    /// Network changes come in bursts; wait for them to settle before looking.
    private func refreshSoon(after seconds: Double) {
        pathDebounce?.cancel()
        pathDebounce = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            refresh()
        }
    }

    private func startPathMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] _ in
            Task { @MainActor in
                self?.updateLocalIP()
                self?.refreshSoon(after: 2)
            }
        }
        monitor.start(queue: DispatchQueue(label: "ipbar.path"))
        pathMonitor = monitor
    }

    // MARK: - Lookup

    private struct Result: Sendable {
        let ip: String
        let country: String?
    }

    /// ipinfo.io gives address and country; ipify is a fallback for the address only.
    private nonisolated static func lookUp() async -> Result? {
        struct IPInfo: Decodable { let ip: String; let country: String? }
        struct IPify: Decodable { let ip: String }

        if let info: IPInfo = await fetch("https://ipinfo.io/json") {
            return Result(ip: info.ip, country: info.country)
        }
        if let info: IPify = await fetch("https://api.ipify.org?format=json") {
            return Result(ip: info.ip, country: nil)
        }
        return nil
    }

    private nonisolated static func fetch<T: Decodable>(_ urlString: String) async -> T? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// "US" → 🇺🇸 (regional indicator symbols).
    private static func flag(_ code: String) -> String {
        let base: UInt32 = 0x1F1E6 - 65  // "A"
        let scalars = code.uppercased().unicodeScalars.compactMap { UnicodeScalar(base + $0.value) }
        return scalars.count == 2 ? String(String.UnicodeScalarView(scalars)) : "🌐"
    }
}
