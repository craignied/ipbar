#!/bin/bash
# Build ipbar, install it to /Applications, and start it at every login.
# Safe to rerun: it rebuilds and replaces the installed copy.
set -euo pipefail

cd "$(dirname "$0")"
APP=/Applications/ipbar.app
LABEL=com.niedertronics.ipbar
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"

echo "Building…"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/ipbar"

# Stop a running copy before replacing it.
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -x ipbar 2>/dev/null || true

echo "Installing ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/ipbar"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null

echo "Setting up start at login…"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$LABEL</string>
    <key>Program</key><string>$APP/Contents/MacOS/ipbar</string>
    <key>RunAtLoad</key><true/>
    <!-- Restart after a crash, but stay quit after "Quit ipbar". -->
    <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
    <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
EOF
launchctl bootstrap "gui/$(id -u)" "$AGENT"

echo "Done. ipbar is in the menu bar and will start at login."
