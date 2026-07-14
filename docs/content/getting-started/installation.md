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

The cask installs `EasyBar.app` into `/Applications`, links the `easybar` CLI into Homebrew's executable path, and installs the calendar and network agents as formula dependencies. Installation starts both agent services automatically.

The agents remain separate applications so macOS can assign Calendar and Location permissions to the processes that use them. Homebrew Services keeps them running independently of the main app.

EasyBar can start without a custom config file. Create `~/.config/easybar/config.toml` only when you want to customize the defaults.

### Upgrading from the self-contained app

No manual migration is required. A normal upgrade installs the agent formulae and starts their services:

```bash
brew update
brew upgrade --cask gi8lino/tap/easybar
```

Quit and reopen EasyBar after upgrading if the previous version is still running.

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

Check the independently managed agent services:

```bash
brew services list | grep easybar
```

Trigger one refresh through the CLI:

```bash
easybar --refresh
```
