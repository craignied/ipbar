#!/bin/bash
# Remove every trace of ipbar: the app, the login agent and the build folder.
set -uo pipefail

cd "$(dirname "$0")"
LABEL=com.niedertronics.ipbar

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
pkill -x ipbar 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf /Applications/ipbar.app .build

echo "ipbar removed. (Delete this folder too if you no longer want the source.)"
