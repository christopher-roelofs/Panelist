import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app/providers.dart';
import '../core/sources/page_source.dart';
import '../platform/window.dart';
import 'fit_mode.dart';
import 'reader_chrome.dart';
import 'zoomable_page.dart';

/// Full-screen single-page reader.
///
/// Owns [source] and closes it when disposed. Saves reading progress on
/// every page turn.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.source, this.initialPage = 0});

  final PageSource source;
  final int initialPage;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  static const _preloadRadius = 2;
  static const _turnDuration = Duration(milliseconds: 220);
  static const _doubleTapWindow = Duration(milliseconds: 250);

  late final PageController _controller;
  late int _page;
  bool _chromeVisible = false;
  bool _locked = false; // current page is zoomed/pannable
  Size _viewport = Size.zero;
  Timer? _singleTapTimer;
  final _pageKeys = <int, GlobalKey<ZoomablePageState>>{};

  PageSource get _src => widget.source;
  ZoomablePageState? get _current => _pageKeys[_page]?.currentState;

  static bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(0, _src.pageCount - 1);
    _controller = PageController(initialPage: _page);
    unawaited(setWindowTitle('${_src.title} — Panelist'));
    if (_isMobile) {
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
    }
  }

  @override
  void dispose() {
    _singleTapTimer?.cancel();
    _controller.dispose();
    unawaited(_src.close());
    unawaited(setWindowTitle('Panelist'));
    if (_isMobile) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Navigation

  void _goTo(int page, {bool animate = true}) {
    final target = page.clamp(0, _src.pageCount - 1);
    if (target == _page) return;
    if (animate && (target - _page).abs() == 1) {
      unawaited(
        _controller.animateToPage(
          target,
          duration: _turnDuration,
          curve: Curves.easeOutCubic,
        ),
      );
    } else {
      _controller.jumpToPage(target);
    }
  }

  void _next() => _goTo(_page + 1);
  void _prev() => _goTo(_page - 1);

  /// Scrolls the current page by [fraction] of the viewport height in
  /// direction [dir], or turns the page if it's already at that edge.
  void _scrollOrTurn(int dir, double fraction) {
    final dy = dir * fraction * _viewport.height;
    final scrolled = _current?.scrollBy(dy, animate: true) ?? false;
    if (!scrolled) _goTo(_page + dir);
  }

  void _onPageChanged(int page) {
    setState(() {
      _page = page;
      _locked = false; // the new page reports its own state
    });
    _pageKeys.removeWhere((i, _) => (i - page).abs() > _preloadRadius + 2);
    unawaited(ref.read(databaseProvider).saveProgress(_src.id, page));
    _preload(page);
  }

  void _preload(int around) {
    if (_viewport == Size.zero) return;
    final fit = ref.read(fitModeProvider);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    for (var d = 1; d <= _preloadRadius; d++) {
      for (final i in [around + d, around - d]) {
        if (i < 0 || i >= _src.pageCount) continue;
        // Errors are ignored here; the page shows them when it's visited.
        unawaited(
          precacheImage(
            pageProvider(_src, i, fit, _viewport, dpr),
            context,
            onError: (_, _) {},
          ),
        );
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
      ref.read(fitModeProvider.notifier).set(ref.read(fitModeProvider).next);

  void _zoom(double factor) => _current?.zoomBy(factor);

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
        _goTo(_src.pageCount - 1, animate: false),
    const SingleActivator(LogicalKeyboardKey.equal): () => _zoom(1.25),
    const SingleActivator(LogicalKeyboardKey.numpadAdd): () => _zoom(1.25),
    const SingleActivator(LogicalKeyboardKey.minus): () => _zoom(0.8),
    const SingleActivator(LogicalKeyboardKey.numpadSubtract): () => _zoom(0.8),
    const SingleActivator(LogicalKeyboardKey.digit0): () =>
        _current?.resetZoom(),
    const SingleActivator(LogicalKeyboardKey.keyM): _cycleFit,
    const SingleActivator(LogicalKeyboardKey.keyF): toggleFullScreen,
    const SingleActivator(LogicalKeyboardKey.f11): toggleFullScreen,
    const SingleActivator(LogicalKeyboardKey.escape): _escape,
  };

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final fit = ref.watch(fitModeProvider);
    ref.listen(fitModeProvider, (_, _) => _preload(_page));

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
                  if (mounted) _preload(_page);
                });
              }
              return Stack(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: _onTapUp,
                    child: PageView.builder(
                      controller: _controller,
                      physics: _locked
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      itemCount: _src.pageCount,
                      onPageChanged: _onPageChanged,
                      itemBuilder: (context, i) => ZoomablePage(
                        key: _pageKeys.putIfAbsent(i, GlobalKey.new),
                        source: _src,
                        index: i,
                        fit: fit,
                        viewport: viewport,
                        isCurrent: i == _page,
                        onLockChanged: (locked) {
                          if (i == _page && locked != _locked) {
                            setState(() => _locked = locked);
                          }
                        },
                        onScrollPastEdge: (dir) {
                          if (i == _page) _goTo(_page + dir);
                        },
                      ),
                    ),
                  ),
                  ReaderChrome(
                    visible: _chromeVisible,
                    title: _src.title,
                    page: _page,
                    pageCount: _src.pageCount,
                    fit: fit,
                    onSeek: (p) => _goTo(p, animate: false),
                    onFitChanged: ref.read(fitModeProvider.notifier).set,
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
