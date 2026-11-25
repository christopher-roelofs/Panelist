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
  library/         library folders, scanning, grouping, browser UI
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
| M0 ✅ | Scaffold, lints, CI, `PageSource`, folder-of-images source, CLI arg / file picker | Linux app opens a folder of images and pages through it |
| M1 ✅ | Great CBZ reader: single page, fit modes, zoom, keyboard/mouse/taps, preloading, saved progress, recent files | 200-page CBZ is smooth on Linux |
| M2 ✅ | Formats: CBR/CB7/CBT via libarchive FFI, PDF via pdfrx | All common formats open |
| M3 ✅ | Double-page spreads (auto wide-page detection, cover offset), per-book settings, ComicInfo.xml | Spreads read correctly |
| M4 | Android: SAF file access, "Open with" intents, touch tuning, memory tuning on phones | Usable on Android phone + tablet |
| M5 | Library: library folders, thumbnails, continue reading, Folders / Series / Publishers views | Home screen with Continue Reading |
| Later | RTL manga, webtoon scroll, panel zoom, OPDS/Komga, Windows/macOS/iOS, AVIF/JXL | |

## Notes and known follow-ups
- Archives other than ZIP are extracted sequentially to a per-process cache
  dir (`~/.cache/dev.panelist.panelist/extracted/book_<pid>_*`), removed on
  close and swept at startup if the owning process is gone. Solid RAR is
  decompressed twice (list pass + extract pass).
- Android: libarchive (+ static liblzma) is built from pinned, hash-checked
  release tarballs by CMake via Gradle (`android/app/src/main/cpp`).
- Android documents are `content://` URIs (stored as the recent's path, with
  persisted read permission). They are read through the descriptor
  (`/proc/self/fd/N` + `pread`/`archive_read_open_fd`/pdfrx `openCustom`),
  because reopening that path fails with EACCES; see `fd_file.dart`.
  Non-seekable providers are copied to `cache/documents/` (not yet swept).
- Release build: `flutter build apk --release` (still signed with the debug
  key; a real release key comes with publishing). The `lintVital*` tasks are
  disabled in `android/build.gradle.kts` because lint crashes on JDK 17.
  Tablet (Tab S6 Lite, release): cold start ~0.6 s; paging through a
  151-page CBZ levels off around 250–300 MB PSS with the image cache sized
  to ~6 screen pages on Android (`_sizeImageCache` in `main.dart`).
- M4 remaining: phone testing, cache/documents sweep.
- Touch: all touch gestures go through one recognizer inside the zoom
  viewer (`_TouchRecognizer` in `zoomable_page.dart`); InteractiveViewer
  only serves mouse/trackpad. One finger: page drag (unzoomed), pan with
  inertia (zoomed), or pull-past-edge page turn when the swipe starts at a
  zoomed page's edge. Two fingers down claim the gesture at once (pinch).
  Page drags use `jumpTo`, not `ScrollPosition.drag`, which would make the
  page view ignore a second finger.
- Reader: paging backwards in fit-width should land at the bottom of the
  previous page.
- Library (M5, in progress): library folders are paths, or on Android SAF
  tree URIs (`pickTree`/`listTree` in `MainActivity.kt`); comics inside are
  read via their document URIs like single files. `LibraryScanner` lists
  every folder on start and on rescan, and reopens only new files or files
  whose size/mtime changed, storing ComicInfo fields in `library_entries`
  and covers as `<support>/covers/<bookId>.png`. Grouping is display-time
  (`library_model.dart`): ComicInfo first, then the parent folder's name,
  then the file name (`comic_name.dart`). Publisher names are shown exactly
  as written (no merging). Progress joins on the content fingerprint, so it
  is shared with books opened outside the library.
  Search matches every word against series, title, file name, publisher
  and `#number`. Covers of comics that left the library are deleted after
  each scan.
- Library follow-ups: watching folders for changes; folders of images as
  library items; mark as read/unread.
- Themes (`lib/app/theme.dart`, Settings screen): System / Light / Dark /
  Black (true black), and an accent (Wallpaper on Android 12+, Grey, Blue
  (default), Teal, Green, Purple, Pink, Amber, Orange). Backgrounds always
  come from a neutral grey scheme, so the accent never tints them; accents
  use the `fidelity` variant so similar hues stay distinguishable. The
  reader is always black.
- End of book (`lib/reader/end_of_book.dart`): one more page after the last
  shows "Finished" and the next issue in the series (`nextInSeries`: by
  number, then year, then file name; other copies of the same book are
  skipped). Reaching it saves the last page as progress, so the book counts
  as read even when it ends on a spread. "Read #n" replaces the reader, so
  Back returns to the library.
