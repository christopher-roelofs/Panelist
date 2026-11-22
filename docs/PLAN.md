# Panelist — Plan

Cross-platform digital comic reader (Flutter/Dart). Open source.
Goal: an excellent reading experience. Initial focus: reading local files.

## Decisions
- **Platforms:** Linux desktop first, then Android. Others (Windows, macOS, iOS) later.
- **Entry point:** open-a-file first. Library comes after the reader is great.
- **Manga (RTL) & webtoon (vertical scroll):** low priority, post-v1.
- **License:** open source (BSD/MIT/Apache-compatible deps only; avoid unrar's license).

## Stack
- State: Riverpod · Routing: go_router · Persistence: drift (SQLite)
- Archives: libarchive via FFI (CBZ/CBR/CB7/CBT, random access, BSD-licensed incl. RAR reader).
  Pure-Dart `archive` package acceptable as a CBZ stopgap.
- PDF: `pdfrx` (pdfium)
- Images: Flutter built-in codecs (JPEG/PNG/WebP/GIF); AVIF/JXL later.

## Architecture
```
lib/
  core/sources/    PageSource interface + implementations per format
  core/imaging/    decode at display size, LRU cache, preloading
  core/metadata/   ComicInfo.xml
  reader/          reader screen, layouts, gestures, keyboard/mouse
  library/         (later) folders, scanning, thumbnails
  platform/        file access (desktop paths, Android SAF)
```
`PageSource`: `int pageCount`, `Future<Uint8List> page(int i)`, `close()`.
Page ordering: natural sort of filenames, skip non-images and junk (`__MACOSX`, `.DS_Store`, `Thumbs.db`).

## Reader quality bar
- Decode at screen resolution; preload ±2 pages; evict outside window; extraction off the UI isolate.
- Fit: screen / width / height / original. Pinch + double-tap zoom to point; pan with edge-to-turn.
- Input: keyboard (←/→, Space/Shift+Space, PgUp/PgDn, Home/End, F fullscreen), mouse wheel, trackpad, configurable tap zones, drag & drop.
- Auto-hiding chrome, page scrubber with thumbnails, black background.
- Progress saved on every page turn; restored instantly.

## Milestones
| # | Goal | Done when |
|---|------|-----------|
| M0 | Scaffold, lints, CI, `PageSource`, folder-of-images source, CLI arg / file picker | Linux app opens a folder of images and pages through it |
| M1 | Great CBZ reader: single page, fit modes, zoom, keyboard/mouse/taps, preloading, saved progress, recent files | 200-page CBZ is smooth on Linux |
| M2 | Formats: CBR/CB7/CBT via libarchive FFI, PDF via pdfrx | All common formats open |
| M3 | Double-page spreads (auto wide-page detection, cover offset), per-book settings, ComicInfo.xml | Spreads read correctly |
| M4 | Android: SAF file access, "Open with" intents, touch tuning, memory tuning on phones | Usable on Android phone + tablet |
| M5 | Library: watched folders, thumbnails, continue reading, series/issue sorting | Home screen with Continue Reading |
| Later | RTL manga, webtoon scroll, panel zoom, OPDS/Komga, Windows/macOS/iOS, AVIF/JXL | |
