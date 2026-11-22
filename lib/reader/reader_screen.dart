import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/imaging/page_image.dart';
import '../core/sources/page_source.dart';

/// Full-screen single-page reader.
///
/// Input: swipe, tap zones (left/right 30%), mouse wheel, keyboard
/// (←/→, ↑/↓, Space/Shift+Space, PgUp/PgDn, Home/End, Esc).
/// Tapping the middle toggles the overlay (title + page scrubber).
///
/// Owns [source] and closes it when disposed.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.source});

  final PageSource source;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  static const _preloadRadius = 2;
  static const _turnDuration = Duration(milliseconds: 220);

  final _controller = PageController();
  int _page = 0;
  bool _chromeVisible = false;
  Size _decodeSize = Size.zero;
  DateTime _lastWheelTurn = DateTime.fromMillisecondsSinceEpoch(0);

  PageSource get _src => widget.source;

  @override
  void dispose() {
    _controller.dispose();
    _src.close();
    super.dispose();
  }

  void _goTo(int page, {bool animate = true}) {
    final target = page.clamp(0, _src.pageCount - 1);
    if (target == _page && _controller.hasClients) return;
    if (animate && (target - _page).abs() == 1) {
      _controller.animateToPage(
        target,
        duration: _turnDuration,
        curve: Curves.easeOutCubic,
      );
    } else {
      _controller.jumpToPage(target);
    }
  }

  void _next() => _goTo(_page + 1);
  void _prev() => _goTo(_page - 1);

  void _onPageChanged(int page) {
    setState(() => _page = page);
    _preload(page);
  }

  void _preload(int around) {
    if (_decodeSize == Size.zero) return;
    for (var d = 1; d <= _preloadRadius; d++) {
      for (final i in [around + d, around - d]) {
        if (i < 0 || i >= _src.pageCount) continue;
        // Errors are ignored here; the page shows them when it's visited.
        precacheImage(
          pageImageAt(_src, i, _decodeSize),
          context,
          onError: (_, _) {},
        );
      }
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    // Claim the event so the PageView doesn't scroll by raw pixels.
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final dy = (e as PointerScrollEvent).scrollDelta.dy;
      if (dy == 0) return;
      // Throttle: trackpads and free-spinning wheels emit bursts.
      final now = DateTime.now();
      if (now.difference(_lastWheelTurn) < const Duration(milliseconds: 180)) {
        return;
      }
      _lastWheelTurn = now;
      dy > 0 ? _next() : _prev();
    });
  }

  void _onTapUp(TapUpDetails d, double width) {
    final x = d.localPosition.dx / width;
    if (x < 0.3) {
      _prev();
    } else if (x > 0.7) {
      _next();
    } else {
      setState(() => _chromeVisible = !_chromeVisible);
    }
  }

  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
    const SingleActivator(LogicalKeyboardKey.arrowRight): _next,
    const SingleActivator(LogicalKeyboardKey.arrowDown): _next,
    const SingleActivator(LogicalKeyboardKey.pageDown): _next,
    const SingleActivator(LogicalKeyboardKey.space): _next,
    const SingleActivator(LogicalKeyboardKey.arrowLeft): _prev,
    const SingleActivator(LogicalKeyboardKey.arrowUp): _prev,
    const SingleActivator(LogicalKeyboardKey.pageUp): _prev,
    const SingleActivator(LogicalKeyboardKey.space, shift: true): _prev,
    const SingleActivator(LogicalKeyboardKey.home): () =>
        _goTo(0, animate: false),
    const SingleActivator(LogicalKeyboardKey.end): () =>
        _goTo(_src.pageCount - 1, animate: false),
    const SingleActivator(LogicalKeyboardKey.escape): () =>
        Navigator.of(context).maybePop(),
  };

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
              final dpr = MediaQuery.devicePixelRatioOf(context);
              final size = bucketDecodeSize(constraints.biggest * dpr);
              if (size != _decodeSize) {
                _decodeSize = size;
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _preload(_page),
                );
              }
              return Stack(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _onTapUp(d, constraints.maxWidth),
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _src.pageCount,
                      onPageChanged: _onPageChanged,
                      itemBuilder: (context, i) => Listener(
                        onPointerSignal: _onPointerSignal,
                        child: _PageView(
                          image: pageImageAt(_src, i, _decodeSize),
                        ),
                      ),
                    ),
                  ),
                  _Chrome(
                    visible: _chromeVisible,
                    title: _src.title,
                    page: _page,
                    pageCount: _src.pageCount,
                    onSeek: (p) => _goTo(p, animate: false),
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

class _PageView extends StatelessWidget {
  const _PageView({required this.image});

  final ImageProvider image;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Image(
        image: image,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, sync) =>
            frame == null ? const SizedBox.shrink() : child,
        errorBuilder: (context, error, _) => Center(
          child: Text(
            "Couldn't load this page\n$error",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}

class _Chrome extends StatelessWidget {
  const _Chrome({
    required this.visible,
    required this.title,
    required this.page,
    required this.pageCount,
    required this.onSeek,
    required this.onBack,
  });

  final bool visible;
  final String title;
  final int page;
  final int pageCount;
  final ValueChanged<int> onSeek;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final bar = Colors.black.withValues(alpha: 0.75);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: Column(
          children: [
            Material(
              color: bar,
              child: SafeArea(
                bottom: false,
                child: ListTile(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: onBack,
                  ),
                  title: Text(title, overflow: TextOverflow.ellipsis),
                ),
              ),
            ),
            const Spacer(),
            Material(
              color: bar,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: pageCount > 1
                            ? Slider(
                                value: page.toDouble(),
                                max: (pageCount - 1).toDouble(),
                                divisions: pageCount - 1,
                                onChanged: (v) => onSeek(v.round()),
                              )
                            : const SizedBox(height: 48),
                      ),
                      Text('${page + 1} / $pageCount'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
