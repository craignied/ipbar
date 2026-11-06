# ipbar

Menu bar app: the menu bar shows the **local** IP (Craig's preference, 2026-11-06);
the menu shows the external IP + country flag. Replaces the App Store app
"Display My IP" (Oleg Tsvetkov, v1.8), which Craig removed on 2026-11-06 after it
got stuck on "Resolving… / You're currently offline" while the network was fine.
Its online check gated its lookup, so it never even made the request.

## Design rules

- Local IP comes from SCDynamicStore (`State:/Network/Global/IPv4` →
  PrimaryInterface → its first IPv4 address), refreshed on every path change.
- **The network monitor is a trigger, never a gate.** `NWPathMonitor` and wake
  notifications only schedule a lookup. "Offline" means the HTTP lookup failed.
  Don't add any reachability check that can skip the lookup; that is exactly the
  bug that killed the app this replaces.
- Lookup: `ipinfo.io/json` (ip + country, no token, 50k requests/month free),
  fallback `api.ipify.org?format=json` (ip only). Don't use Oleg's
  `apps.olegtsvetkov.com` endpoint; it's his private backend.
- No third-party dependencies. No Xcode project: SwiftPM executable plus
  `install.sh`, which wraps it into an ad-hoc-signed `.app`
  (`Info.plist` sets `LSUIElement`, so there's no Dock icon).
- Start at login uses a LaunchAgent (`com.niedertronics.ipbar`), not
  SMAppService/Login Items, so rebuilding never needs re-approval.
  `KeepAlive.SuccessfulExit=false`: a crash restarts it, but Quit stays quit.
- Public repo (github.com/craignied/ipbar): keep personal data (real IPs,
  hostnames, paths) out of code, docs and commits. README examples use
  203.0.113.x (the reserved documentation range).

## Build / run

- `./install.sh` builds, installs to `/Applications/ipbar.app`, and (re)loads the
  agent. Rerun after any change. `./uninstall.sh` removes all traces.
- Quick check: `swift build -c release`.
- To see it, screenshot the menu bar strip: `screencapture -x -R 0,0,3000,40 out.png`.

## Leftover from Display My IP

`sfltool dumpbtm` still lists a stale login-item record for
`com.olegtsvetkov.MyIPDisplay`. macOS prunes these for deleted apps on its own;
the only manual fix is `sfltool resetbtm`, which resets every login item, so
leave it alone.
