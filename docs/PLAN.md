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
| M4 ✅ | Android: SAF file access, "Open with" intents, touch tuning, memory tuning on phones | Usable on Android phone + tablet |
| M5 ✅ | Library: library folders, thumbnails, continue reading, Folders / Series / Publishers views | Home screen with Continue Reading |
| M6 | Metadata management (desktop): book IDs that ignore metadata files; ComicInfo editor (one issue, then bulk); save into archives (CBZ in place, CBR→CBZ, via temp file); Metron and Comic Vine lookup; rename/organise by template, promo clean-up, publisher aliases. Builds on the ComicTools ideas | The PC library can be tagged and organised from Panelist |
| M7 | Library over the local network: the desktop app serves the library (OPDS-style); phone/tablet browse, read or download from it, and send reading progress back (also for comics copied onto the device). Metadata is edited on the PC only | Progress read on the tablet shows on the PC |
| Later | RTL manga, webtoon scroll, panel zoom, OPDS/Komga, Windows/macOS/iOS, AVIF/JXL | |

## Distribution (before the first release)

### Linux
The release bundle (`build/linux/x64/release/bundle`) carries the app,
Flutter engine, pdfium, sqlite and plugins, but uses the system's GTK 3,
X11/Wayland, fonts and **libarchive** (CBR and most CBZ won't open without
it), and needs **glibc 2.34+** (Ubuntu 22.04, Debian 12, Fedora 35 or
newer).
- Plan: **Flatpak** on the GNOME runtime (GTK and libarchive included;
  works on any distro with Flatpak; Flathub for open-source apps).
- Alternatives: AppImage (one file, bundles libarchive; build on an old
  distro for glibc), or a tarball with libarchive added to `lib/`.

### Windows
1. `flutter create --platforms=windows .` to add `windows/`.
2. Build in **GitHub Actions** (`windows-latest` has Visual Studio 2022);
   Flutter can't cross-compile from Linux. Needs a GitHub remote.
3. Ship **`archive.dll`** next to the exe (the loader already looks for
   it): build libarchive with vcpkg in the same job, with zlib, bzip2, xz,
   zstd, lz4 (all permissive; libarchive's own RAR reader, no unrar).
   pdfium is bundled by pdfrx.
4. Package: start with a zip of `build/windows/x64/runner/Release` plus
   the MSVC runtime DLLs (`msvcp140.dll`, `vcruntime140*.dll`); then an
   **Inno Setup** installer (Start menu, uninstaller, .cbz/.cbr/.pdf
   "Open with"). MSIX (`msix` package) only if we go to the Store.
5. Code signing, to avoid SmartScreen warnings: **SignPath Foundation**
   (free for open source built in public CI), else Azure Trusted Signing
   (~$10/month) or a certificate; unsigned is OK for early testing.
6. Check on real Windows: drive-letter paths, folder picker, drag and
   drop, full screen.

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
- Android copies of stream-only documents (some cloud providers) live in
  `cache/documents`: deleted when the source closes, and copies older than
  the process are swept at launch. Deleting on close isn't yet tested with
  a real cloud file.
- Touch: all touch gestures go through one recognizer inside the zoom
  viewer (`_TouchRecognizer` in `zoomable_page.dart`); InteractiveViewer
  only serves mouse/trackpad. One finger: page drag (unzoomed), pan with
  inertia (zoomed), or pull-past-edge page turn when the swipe starts at a
  zoomed page's edge. Two fingers down claim the gesture at once (pinch).
  Page drags use `jumpTo`, not `ScrollPosition.drag`, which would make the
  page view ignore a second finger.
- Reader: paging backwards in fit-width should land at the bottom of the
  previous page.
- Library (M5): library folders are paths, or on Android SAF
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
- Auto refresh (`lib/library/library_refresh.dart`): on disk, every library
  folder is watched (Dart's recursive watch misses subfolders on Linux) and
  re-watched after each scan; changes are debounced 2 s into one scan.
  Android `content://` folders can't be watched, so the app rescans when it
  comes back to the foreground, at most every 30 s.
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
- Read state: `Books.finished`, set on reaching the last page or by
  "Mark as read" (long-press an issue, series, publisher or folder; or the
  Continue reading menu). Paging back keeps it; "Mark as unread" clears it,
  returns to page 1 and leaves recent books, keeping reader settings.
  Books with `lastOpened` at the epoch (`notRecent`) aren't in recent books.
- No database migrations until the first release: the schema is version 1;
  after changing it, clear the app's data on test devices.
- Book IDs: CBZ uses `pagesFingerprint` (SHA-1 of each page's CRC-32 and
  size, in reading order, from the central directory), so writing
  ComicInfo.xml or re-zipping keeps progress. CBR/CB7/CBT and PDF still use
  `fileFingerprint` (size + first/last 64 KiB); M6 must move progress to the
  new ID when it converts CBR→CBZ, rewrites CB7/CBT, or removes pages.
- ComicInfo editor (M6, desktop only): "Edit details" in an issue's
  long-press sheet opens a form for the ComicInfo v2.0 fields. Saving
  rewrites the CBZ through a hidden temp file beside it (pages copied
  without recompression, archive comment kept), checks the copy has the same
  pages and the new XML, then renames it over the original. Fields not in
  the form (`<Pages>`, unknown elements) are kept; new ones go in schema
  order. Other formats say "Only CBZ files can be edited for now" (step 3).
  Publisher and series groups have "Edit publisher" / "Edit series", which
  sets that field in every CBZ in the group (skipping other formats and
  files already set). Series from names: the folder name is used only when
  the file name has no series or the folder gives a fuller name for the
  same series, so pack folders (`2026.11.18 DC Week`) and publisher folders
  don't name the series.
- Folders of images aren't comics: the "Open folder of images" button and
  `FolderPageSource` were removed (M0 had them), and the library only
  lists comic files.
- CBR→CBZ (M6 step 3, desktop): "Convert to CBZ" on an issue, and
  "Convert N to CBZ" on series, publisher and folder sheets (CBR, CB7, CBT,
  RAR, 7z, tar by name). Every file is extracted with libarchive into a
  hidden temp folder beside the comic and zipped (pages stored as-is,
  ComicInfo and other files deflated; `__MACOSX` and dot files dropped;
  unsafe paths made relative). The CBZ is checked page by page (names,
  CRC-32, sizes, reading order) before it's renamed into place; an existing
  CBZ is never overwritten. A ZIP named .cbr is just renamed. `moveBook`
  moves progress and settings to the new ID; the original goes to the
  trash (`gio trash`; elsewhere it's kept and the result says so). PDFs
  aren't converted. CBZs come out ~2–3% bigger than RAR.
  A folder's sheet covers all its subfolders; breadcrumbs (the library
  folder, the current folder, a publisher or series, "All …") open the same
  sheet on right-click / long-press. Converting can be stopped between
  comics.
- Metron lookup (M6 step 4, desktop): API token (Bearer; Metron dropped
  username/password) set in Settings → Comic details, stored in the
  settings table. `MetronClient` spaces requests ~3 s apart (under the
  burst limit), waits out 429s per Retry-After, caches per session.
  Matching: a `[issue_id:N]` in Notes (MetronTagger's and ours) is used
  directly; otherwise `issue/?series_name=&number=` and `chooseMatch`
  (same normalised name and number; year within one of cover, store or
  series start) must leave exactly one. Mapping follows MetronTagger
  (Volume = series start year, credits by role, Web, GTIN, Notes line).
  Editor: "Look up on Metron" fills the form to review. Sheets: "Look up on
  Metron" for an issue; "Look up N on Metron" for groups/folders, which
  converts CBR first, saves sure matches and lists the rest with
  "Choose…". No word lists: `findIssue` tries the name as written, then
  the same words written differently (`2000AD` → `2000 AD`, `A - B` → `A: B`;
  still a sure match), then shorter names (trailing words dropped, the last
  half of `A - B`), which only give a *likely* match for the user to
  confirm, unless the series' `alt_names` on Metron include the comic's
  name ("2000AD Prog" for "2000 AD"), which makes it sure (the details call
  is needed to save anyway). At most 6 searches per comic. Fewer calls:
  answers are cached on disk (`metron.json` in the app cache folder;
  details 30 days, searches 1 day), and a name once matched (sure or
  confirmed) remembers its Metron series, so later issues need one search
  by `series_id`.
  Title when Metron has no title of its own: all story titles joined with
  "; " (decided). Step 5 (rename by template) should default to a template
  without `{title}` (e.g. `{series} {number} ({year})`) and shorten
  `{title}` when used (anthologies list one story per serial). Anthology
  titles are joined with "; " (titles contain commas).
- Lookup providers (M6, desktop): `lib/core/metadata/lookup/`. A
  `LookupProvider` only searches (`search`, `searchSeries`), fetches and
  applies (`apply`), reads its own ID marker (`knownId`) and lists series
  aliases; the matching (`findIssue`, `searchForms`, `chooseMatch`, series
  memory) is shared, and `ApiClient` does spacing, 429/420 retries and the
  cache (`lookup.json`; keys never cached). Metron: `[issue_id:N]`, 3.1 s
  apart. Comic Vine: volume search, then one `issues/` filter over the
  same-named volumes (`volume:A|B,issue_number:N`), detail
  `issue/4000-N/` plus `volume/4050-N/`; `[Issue ID N]` like ComicTagger
  (also reads `[CVDBN]` and a 4000- Web link); description HTML to text;
  1.1 s apart (CV allows ~200/hour per resource). Settings → Comic details:
  one key per service and "Look up first on". Buttons say "Look up info".
  Batch: per comic, a known ID of any provider wins; else providers in
  order until one is sure; a key refused / limit reached drops that
  provider for the run. The choose dialog searches in order until
  something fits, with "Search <next> too". A publisher in ComicInfo breaks
  ties between same-named series. Adding a provider: a class plus an entry
  in `lookupServices`.
