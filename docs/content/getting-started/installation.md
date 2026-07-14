# Installation

EasyBar is distributed through Homebrew in the `gi8lino/tap` tap.

## Install

Add the tap:

```bash
brew tap gi8lino/tap
```

Install EasyBar:

```bash
brew install --cask gi8lino/tap/easybar
```

The cask installs `EasyBar.app` into `/Applications` and links the `easybar` CLI into Homebrew's executable path. The self-contained app includes and supervises the calendar and network helper agents.

EasyBar can start without a custom config file. Create `~/.config/easybar/config.toml` only when you want to customize the defaults.

### Migrating from the old formulas

If you previously installed EasyBar and its agents as formulas, stop their services and remove them before installing the cask. This avoids duplicate processes and a conflict with the old `easybar` CLI link:

```bash
brew services stop gi8lino/tap/easybar
brew services stop gi8lino/tap/easybar-calendar-agent
brew services stop gi8lino/tap/easybar-network-agent
brew uninstall --formula gi8lino/tap/easybar
brew uninstall --formula gi8lino/tap/easybar-calendar-agent
brew uninstall --formula gi8lino/tap/easybar-network-agent
brew install --cask gi8lino/tap/easybar
```

This does not remove your configuration or runtime logs.

## Launch EasyBar

Open EasyBar from Finder, Spotlight, or the command line:

```bash
open -a EasyBar
```

## Verify the install

Check that Homebrew installed the app:

```bash
test -d /Applications/EasyBar.app && echo "EasyBar is installed"
```

Check running processes:

```bash
pgrep -fl EasyBar
pgrep -fl EasyBarCalendarAgent
pgrep -fl EasyBarNetworkAgent
```

Trigger one refresh through the CLI:

```bash
easybar --refresh
```
