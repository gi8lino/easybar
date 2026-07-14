# macOS Quarantine

EasyBar is not notarized.

Notarization is one of Apple's distribution checks. In practice, it means sending binaries to Apple and dealing with their packaging and approval flow.

The Homebrew install is meant to work out of the box in the common case. If macOS blocks EasyBar or one of its helper agents with a Gatekeeper or malware verification warning, remove the quarantine attribute and launch the app again.

## Remove quarantine

If macOS blocks the app, helper agents, or CLI, run:

```bash
xattr -dr com.apple.quarantine /Applications/EasyBar.app
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
