# macOS Quarantine

EasyBar is not notarized.

Notarization is one of Apple's distribution checks. In practice, it means sending binaries to Apple and dealing with their packaging and approval flow.

The Homebrew install is meant to work out of the box in the common case. If macOS blocks EasyBar or one of its helper agents with a Gatekeeper or malware verification warning, remove the quarantine attribute and start the services again.

## Remove quarantine

If macOS blocks the app, helper agents, or CLI, run:

```bash
xattr -dr com.apple.quarantine "$(brew --prefix)/opt/easybar/libexec/EasyBar.app"
xattr -dr com.apple.quarantine "$(brew --prefix)/opt/easybar-calendar-agent/libexec/EasyBarCalendarAgent.app"
xattr -dr com.apple.quarantine "$(brew --prefix)/opt/easybar-network-agent/libexec/EasyBarNetworkAgent.app"
xattr -d com.apple.quarantine "$(command -v easybar)"
```

Then restart the services:

```bash
brew services start gi8lino/tap/easybar-calendar-agent
brew services start gi8lino/tap/easybar-network-agent
brew services start gi8lino/tap/easybar
```

## Launch manually

If you want to check whether the app launches outside Homebrew services:

```bash
open "$(brew --prefix)/opt/easybar/libexec/EasyBar.app"
```

If manual launch works but the service does not, check the Homebrew service logs.
