# Panelist

A cross-platform comic reader built with Flutter, focused on a great reading
experience for local files.

Status: early development — see [docs/PLAN.md](docs/PLAN.md).

## Run

```bash
flutter run -d linux                         # opens the home screen
flutter run -d linux -a /path/to/comic-folder  # opens a comic directly
```

Linux build dependencies (Ubuntu):

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libarchive-dev
```

## Reader controls

| Action | Keyboard | Mouse / touch |
|---|---|---|
| Next page | → ↓ Space PgDn | Click/tap right 30%, wheel down, swipe |
| Previous page | ← ↑ Shift+Space PgUp | Click/tap left 30%, wheel up, swipe |
| First / last page | Home / End | Page slider |
| Toggle overlay | — | Click/tap centre |
| Close | Esc | Back button |

## Develop

```bash
flutter analyze && flutter test
```

## License

Apache License 2.0 — see [LICENSE](LICENSE).
