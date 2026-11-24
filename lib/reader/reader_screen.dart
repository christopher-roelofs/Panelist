import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app/providers.dart';
import '../core/sources/page_source.dart';
import '../data/book_extensions.dart';
import '../data/database.dart';
import '../platform/window.dart';
import 'book_info_dialog.dart';
import 'fit_mode.dart';
import 'reader_chrome.dart';
import 'reader_settings.dart';
import 'spreads.dart';
import 'zoomable_page.dart';

/// Full-screen reader showing one page or a two-page spread at a time.
///
/// Owns [source] and closes it when disposed. Saves reading progress on
/// every turn and remembers display settings per book.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.source,
    this.book,
    this.initialPage = 0,
  });

  final PageSource source;

  /// The stored row for this book (settings, cached sizes, metadata).
  final Book? book;
  final int initialPage;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  static const _preloadRadius = 2;
  static const _turnDuration = Duration(milliseconds: 220);
  static const _doubleTapWindow = Duration(milliseconds: 250);

  late ReaderSettings _settings;
  late List<Size?> _sizes;

  /// Reading units (one page or a spread). Rebuilt when the layout, the
  /// viewport orientation or the known page sizes change.
  List<List<int>> _units = const [];
  PageController? _controller;
  int _unit = 0;

  /// First page of the current unit: the reading position that survives
  /// re-pairing, and what is saved as progress.
  late int _anchorPage;

  bool _chromeVisible = false;
  bool _locked = false; // current unit is zoomed/pannable
  Size _viewport = Size.zero;
  Timer? _singleTapTimer;
  final _pageKeys = <int, GlobalKey<ZoomablePageState>>{};

  PageSource get _src => widget.source;
  ZoomablePageState? get _current => _pageKeys[_unit]?.currentState;
  String get _title => widget.book?.displayTitle ?? _src.title;

  static bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    final defaults = ref.read(readerDefaultsProvider);
    _settings = widget.book?.settingsOver(defaults) ?? defaults;
    _anchorPage = widget.initialPage.clamp(0, _src.pageCount - 1);
    final cached = widget.book?.cachedPageSizes;
    _sizes = cached ?? List.filled(_src.pageCount, null);
    if (cached == null) unawaited(_probeSizes());
    unawaited(setWindowTitle('$_title — Panelist'));
    if (_isMobile) {
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
    }
  }

  @override
  void dispose() {
    _singleTapTimer?.cancel();
    _controller?.dispose();
    unawaited(_src.close());
    unawaited(setWindowTitle('Panelist'));
    if (_isMobile) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    super.dispose();
  }

  /// Learns page sizes (for spread pairing) in the background and caches
  /// them, after giving the first page a head start.
  Future<void> _probeSizes() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    try {
      final sizes = await _src.probePageSizes();
      if (!mounted) return;
      setState(() => _sizes = sizes);
      await ref
          .read(databaseProvider)
          .savePageSizes(_src.id, encodePageSizes(sizes));
    } on Object {
      // Pairing falls back to treating pages as portrait.
    }
  }

  // ---------------------------------------------------------------------------
  // Units

  /// Rebuilds the units if needed for [viewport]; keeps the anchor page in
  /// view by starting a fresh controller at its unit.
  void _syncUnits(Size viewport) {
    final units = buildSpreads(
      _sizes,
      twoPages: _settings.showsTwoPages(viewport),
      coverAlone: _settings.coverAlone,
    );
    if (_controller != null && _sameUnits(units, _units)) return;
    _units = units;
    _unit = unitOfPage(units, _anchorPage);
    _locked = false;
    _pageKeys.clear();
    final old = _controller;
    _controller = PageController(initialPage: _unit);
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  static bool _sameUnits(List<List<int>> a, List<List<int>> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!listEquals(a[i], b[i])) return false;
    }
    return true;
  }

  void _updateSettings(ReaderSettings s) {
    if (s == _settings) return;
    setState(() => _settings = s);
    ref.read(readerDefaultsProvider.notifier).set(s);
    unawaited(
      ref
          .read(databaseProvider)
          .saveBookSettings(
            _src.id,
            fitMode: s.fit.name,
            layoutMode: s.layout.name,
            coverAlone: s.coverAlone,
          ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _preload(_unit);
    });
  }

  // ---------------------------------------------------------------------------
  // Navigation

  void _goTo(int unit, {bool animate = true}) {
    final target = unit.clamp(0, _units.length - 1);
    final controller = _controller;
    if (target == _unit || controller == null) return;
    if (animate && (target - _unit).abs() == 1) {
      unawaited(
        controller.animateToPage(
          target,
          duration: _turnDuration,
          curve: Curves.easeOutCubic,
        ),
      );
    } else {
      controller.jumpToPage(target);
    }
  }

  void _next() => _goTo(_unit + 1);
  void _prev() => _goTo(_unit - 1);

  /// Scrolls the current unit by [fraction] of the viewport height in
  /// direction [dir], or turns the page if it's already at that edge.
  void _scrollOrTurn(int dir, double fraction) {
    final dy = dir * fraction * _viewport.height;
    final scrolled = _current?.scrollBy(dy, animate: true) ?? false;
    if (!scrolled) _goTo(_unit + dir);
  }

  void _onUnitChanged(int unit) {
    setState(() {
      _unit = unit;
      _anchorPage = _units[unit].first;
      _locked = false; // the new unit reports its own state
    });
    _pageKeys.removeWhere((i, _) => (i - unit).abs() > _preloadRadius + 2);
    unawaited(ref.read(databaseProvider).saveProgress(_src.id, _anchorPage));
    _preload(unit);
  }

  void _preload(int around) {
    if (_viewport == Size.zero) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    for (var d = 1; d <= _preloadRadius; d++) {
      for (final u in [around + d, around - d]) {
        if (u < 0 || u >= _units.length) continue;
        final unit = _units[u];
        for (final page in unit) {
          // Errors are ignored here; the page shows them when it's visited.
          unawaited(
            precacheImage(
              unitPageProvider(
                _src,
                page,
                unit.length,
                _settings.fit,
                _viewport,
                dpr,
              ),
              context,
              onError: (_, _) {},
            ),
          );
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Input

  /// Edge taps turn pages immediately. In the centre, a single tap toggles
  /// the overlay and a double tap zooms, so centre single taps wait briefly
  /// for a possible second tap; edge taps never wait.
  void _onTapUp(TapUpDetails d) {
    final x = d.localPosition.dx / _viewport.width;
    if (x < 0.3 || x > 0.7) {
      _singleTapTimer?.cancel();
      x < 0.3 ? _prev() : _next();
      return;
    }
    if (_singleTapTimer?.isActive ?? false) {
      _singleTapTimer!.cancel();
      _current?.toggleZoomAt(d.globalPosition);
      return;
    }
    _singleTapTimer = Timer(_doubleTapWindow, () {
      if (mounted) setState(() => _chromeVisible = !_chromeVisible);
    });
  }

  Future<void> _escape() async {
    if (await isFullScreen()) {
      await setFullScreen(false);
    } else if (mounted) {
      await Navigator.of(context).maybePop();
    }
  }

  void _cycleFit() =>
      _updateSettings(_settings.copyWith(fit: _settings.fit.next));

  void _cycleLayout() => _updateSettings(
    _settings.copyWith(
      layout: LayoutMode
          .values[(_settings.layout.index + 1) % LayoutMode.values.length],
    ),
  );

  void _toggleCover() =>
      _updateSettings(_settings.copyWith(coverAlone: !_settings.coverAlone));

  void _zoom(double factor) => _current?.zoomBy(factor);

  void _showInfo() {
    final book = widget.book;
    if (book == null) return;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => BookInfoDialog(book: book),
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
    const SingleActivator(LogicalKeyboardKey.arrowRight): _next,
    const SingleActivator(LogicalKeyboardKey.arrowLeft): _prev,
    const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
        _scrollOrTurn(1, 0.2),
    const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
        _scrollOrTurn(-1, 0.2),
    const SingleActivator(LogicalKeyboardKey.space): () =>
        _scrollOrTurn(1, 0.9),
    const SingleActivator(LogicalKeyboardKey.space, shift: true): () =>
        _scrollOrTurn(-1, 0.9),
    const SingleActivator(LogicalKeyboardKey.pageDown): () =>
        _scrollOrTurn(1, 0.9),
    const SingleActivator(LogicalKeyboardKey.pageUp): () =>
        _scrollOrTurn(-1, 0.9),
    const SingleActivator(LogicalKeyboardKey.home): () =>
        _goTo(0, animate: false),
    const SingleActivator(LogicalKeyboardKey.end): () =>
        _goTo(_units.length - 1, animate: false),
    const SingleActivator(LogicalKeyboardKey.equal): () => _zoom(1.25),
    const SingleActivator(LogicalKeyboardKey.numpadAdd): () => _zoom(1.25),
    const SingleActivator(LogicalKeyboardKey.minus): () => _zoom(0.8),
    const SingleActivator(LogicalKeyboardKey.numpadSubtract): () => _zoom(0.8),
    const SingleActivator(LogicalKeyboardKey.digit0): () =>
        _current?.resetZoom(),
    const SingleActivator(LogicalKeyboardKey.keyM): _cycleFit,
    const SingleActivator(LogicalKeyboardKey.keyD): _cycleLayout,
    const SingleActivator(LogicalKeyboardKey.keyO): _toggleCover,
    const SingleActivator(LogicalKeyboardKey.keyI): _showInfo,
    const SingleActivator(LogicalKeyboardKey.keyF): toggleFullScreen,
    const SingleActivator(LogicalKeyboardKey.f11): toggleFullScreen,
    const SingleActivator(LogicalKeyboardKey.escape): _escape,
  };

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: _shortcuts,
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final viewport = constraints.biggest;
              if (viewport != _viewport) {
                _viewport = viewport;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _preload(_unit);
                });
              }
              _syncUnits(viewport);
              final unit = _units[_unit];
              return Stack(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: _onTapUp,
                    child: PageView.builder(
                      key: ObjectKey(_controller),
                      controller: _controller,
                      physics: _locked
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      itemCount: _units.length,
                      onPageChanged: _onUnitChanged,
                      itemBuilder: (context, u) => ZoomablePage(
                        key: _pageKeys.putIfAbsent(u, GlobalKey.new),
                        source: _src,
                        pages: _units[u],
                        fit: _settings.fit,
                        viewport: viewport,
                        isCurrent: u == _unit,
                        onLockChanged: (locked) {
                          if (u == _unit && locked != _locked) {
                            setState(() => _locked = locked);
                          }
                        },
                        onScrollPastEdge: (dir) {
                          if (u == _unit) _goTo(_unit + dir);
                        },
                        onPageDrag: (d) => _controller!.position.drag(d, () {}),
                      ),
                    ),
                  ),
                  ReaderChrome(
                    visible: _chromeVisible,
                    title: _title,
                    pages: unit,
                    pageCount: _src.pageCount,
                    unit: _unit,
                    unitCount: _units.length,
                    settings: _settings,
                    onSeek: (u) => _goTo(u, animate: false),
                    onSettingsChanged: _updateSettings,
                    onInfo: widget.book == null ? null : _showInfo,
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
