# ipbar

A tiny macOS menu bar app that shows your public IP address and country flag at a glance.

```
🇺🇸 203.0.113.42
```

Click it for a menu with **Copy** (⌘C), the country name, when it last checked, **Refresh** (⌘R) and **Quit**.

## Install

Needs macOS 14 or later and Apple's command line tools (`xcode-select --install`, or a full Xcode).

```bash
git clone https://github.com/craignied/ipbar.git
cd ipbar
./install.sh
```

This builds the app, puts it in `/Applications/ipbar.app`, and adds a login agent so it starts every time you log in. No Apple Developer account, signing or App Store involved. Rerun `./install.sh` after pulling updates.

## Uninstall

```bash
./uninstall.sh
```

Removes the app, the login agent (`~/Library/LaunchAgents/com.niedertronics.ipbar.plist`) and the build folder. Then delete the cloned folder.

## How it works

- Looks up the address from [ipinfo.io](https://ipinfo.io) (address and country), falling back to [ipify](https://www.ipify.org) (address only) if that fails. No account or API key needed.
- Checks every 5 minutes, again shortly after any network change or wake from sleep, and every 30 seconds while lookups are failing.
- It always tries the lookup. It says "Offline" only when the lookup itself fails, never because macOS *thinks* the network is down. If the network drops after a successful check, the last address stays shown with a `?` after it.
- If you choose **Quit**, it stays quit until your next login; if it crashes, it restarts.

## License

MIT
