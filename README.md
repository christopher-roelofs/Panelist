# Panelist

A cross-platform comic reader built with Flutter, focused on a great reading
experience for local files.

Status: early development — see [docs/PLAN.md](docs/PLAN.md).

## Run

```bash
flutter run -d linux                            # home screen with recent books
flutter run -d linux -a "/path/to/Comic 01.cbz" # open a comic directly
```

Opens CBZ files and folders of images. Drop a file on the window, use
**Open file / Open folder**, or pick up where you left off under
*Continue reading*. Progress is saved on every page turn and follows the
file even if it is renamed or moved.

Linux build dependencies (Ubuntu):

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libarchive-dev
```

> The SQLite build hook needs a real `clang` first on `PATH`. If `clang` is a
> symlink to gcc, put `/usr/lib/llvm-*/bin` ahead of it.

## Reader controls

| Action | Keyboard | Mouse / touch |
|---|---|---|
| Next / previous page | → / ← | Click/tap right or left 30%, swipe |
| Scroll down / up, then turn | Space, PgDn, ↓ / Shift+Space, PgUp, ↑ | Mouse wheel (pauses at page edge) |
| First / last page | Home / End | Page slider |
| Zoom in / out / reset | + / − / 0 | Pinch, Ctrl+wheel, double-tap centre |
| Cycle fit mode (screen, width, height, original) | M | Overlay menu |
| Fullscreen | F, F11 | Overlay button |
| Toggle overlay | — | Click/tap centre |
| Close (or leave fullscreen) | Esc | Back button |

## Develop

```bash
flutter analyze && flutter test
```

## License

Apache License 2.0 — see [LICENSE](LICENSE).
