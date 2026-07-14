# macOS Quarantine

EasyBar is not notarized.

Notarization is one of Apple's distribution checks. In practice, it means sending binaries to Apple and dealing with their packaging and approval flow.

The Homebrew packages remove the quarantine attribute from the installed app, CLI, and agent applications automatically, so Homebrew installations work without a Gatekeeper warning. The manual steps below are only needed when installing the release archive yourself or recovering an older installation.

## Remove quarantine

If macOS blocks the app, helper agents, or CLI, run:

```bash
xattr -dr com.apple.quarantine /Applications/EasyBar.app
xattr -dr com.apple.quarantine "$(brew --prefix easybar-calendar-agent)/libexec/EasyBarCalendarAgent.app"
xattr -dr com.apple.quarantine "$(brew --prefix easybar-network-agent)/libexec/EasyBarNetworkAgent.app"
xattr -d com.apple.quarantine "$(command -v easybar)"
```

Then launch EasyBar again:

```bash
open -a EasyBar
```

## Launch manually

To check whether the app launches normally:

```bash
open /Applications/EasyBar.app
```
