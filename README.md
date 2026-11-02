# btmx-focus <img src="docs/images/icon.png" alt="The btmx-focus icon: a long italic ƒ over a red progress ring" height="40" align="top">

A native macOS menu-bar focus timer: 30 minutes of focus, 5 minutes of rest, one click away.

<p align="center">
  <img src="docs/images/popover.png" alt="The btmx-focus popover: a progress ring around Focus, 24:13 and the pause button, with Today 0/10 below" width="240">
</p>

## Install

Requires macOS 15 or newer on Apple silicon.

btmx-focus is not notarized by Apple. Installation using brew removes the quarantine
flag from btmx-focus.app so macOS opens it without asking.

### Using brew

```sh
brew install bytemux/tap/btmx-focus
```

### Manual install

Download the DMG from [Releases](https://github.com/bytemux/btmx-focus/releases).

After download, allow the first launch in System Settings → Privacy & Security → Open Anyway.

## Develop

- [Build and run](docs/building.md)
- [Testing](docs/testing.md)
- [Glossary](GLOSSARY.md) and [decisions](docs/adr/)
- [Roadmap](https://github.com/bytemux/btmx-focus/issues)
