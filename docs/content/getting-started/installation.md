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

The self-contained app includes the calendar and network helper agents. The formula also installs the `easybar` CLI.

EasyBar can start without a custom config file. Create `~/.config/easybar/config.toml` only when you want to customize the defaults.

## Start services

Start EasyBar:

```bash
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
pgrep -fl EasyBarCalendarAgent
pgrep -fl EasyBarNetworkAgent
```

Trigger one refresh through the CLI:

```bash
easybar --refresh
```
