# Installation

EasyBar is distributed through Homebrew in the `gi8lino/tap` tap.

## Install

Add the tap:

```bash
brew tap gi8lino/tap
```

Install EasyBar:

```bash
brew install gi8lino/tap/easybar
```

This also installs the calendar and network helper agents.

## Start services

Start EasyBar and both helper agents:

```bash
brew services start gi8lino/tap/easybar-calendar-agent
brew services start gi8lino/tap/easybar-network-agent
brew services start gi8lino/tap/easybar
```

## Verify the install

Check Homebrew services:

```bash
brew services list | grep easybar
```

Check running processes:

```bash
pgrep -fl EasyBar
pgrep -fl easybar-calendar-agent
pgrep -fl easybar-network-agent
```

Trigger one refresh through the CLI:

```bash
easybar --refresh
```

## Next steps

- [macOS Quarantine](macos-quarantine.md)
- [Config Path](configuration-path.md)
- [AeroSpace Integration](aerospace.md)
