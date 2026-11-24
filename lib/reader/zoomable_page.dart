import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/sources/page_source.dart';
import 'fit_mode.dart';

/// One reading unit (a page or a two-page spread): lays the pages out for a
/// [FitMode] at a common height, and supports
/// pinch / Ctrl+wheel / double-tap zoom and panning.
///
/// The page is laid out on a "content" canvas at least as large as the
/// viewport; the [InteractiveViewer] transform (scale ≥ 1) moves over it.
/// In fit-width mode a tall page is simply content taller than the viewport,
/// so scrolling through it is a vertical pan.
class ZoomablePage extends StatefulWidget {
  const ZoomablePage({
    super.key,
    required this.source,
    required this.pages,
    required this.fit,
    required this.viewport,
    required this.isCurrent,
    required this.onLockChanged,
    required this.onScrollPastEdge,
    this.onPageDrag,
  });

  final PageSource source;

  /// The page indices shown together (one page, or a two-page spread in
  /// reading order).
  final List<int> pages;
  final FitMode fit;

  /// Logical size of the reader viewport.
  final Size viewport;

  /// Whether this is the page the reader is showing (not a neighbour).
  final bool isCurrent;

  /// Called with `true` while the page is zoomed or wider than the viewport,
  /// meaning horizontal drags should pan instead of turning pages.
  final ValueChanged<bool> onLockChanged;

  /// Called when the mouse wheel is turned at the top (-1) or bottom (+1)
  /// edge of the page.
  final ValueChanged<int> onScrollPastEdge;

  /// Starts a page-turning drag (typically `PageController.position.drag`).
  ///
  /// The [InteractiveViewer]'s scale recognizer also claims one-finger
  /// pans, and wins the gesture arena when a fast flick's first move
  /// crosses both its slop and the page view's at once. So while the page
  /// isn't zoomed, horizontal touch drags are recognised *inside* the
  /// viewer, ahead of it, and forwarded here. A second finger hands the
  /// gesture back to the viewer for pinch zoom.
  final Drag Function(DragStartDetails details)? onPageDrag;

  @override
  State<ZoomablePage> createState() => ZoomablePageState();
}

class ZoomablePageState extends State<ZoomablePage>
    with SingleTickerProviderStateMixin {
  static const _maxScale = 8.0;
  static const _doubleTapScale = 2.5;

  final _tc = TransformationController();
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Matrix4Tween? _tween;

  final _streams = <ImageStream>[];
  final _listeners = <ImageStreamListener>[];
  List<Size?> _sizes = const [];
  Object? _error;
  int _zoomLevel = 1;
  bool _locked = false;
  Drag? _pageDrag;
  DateTime _lastScrollMove = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _tc.addListener(_onTransform);
    _anim.addListener(() {
      _tc.value = _tween!.transform(Curves.easeOutCubic.transform(_anim.value));
    });
    _anim.addStatusListener((s) {
      if (s == AnimationStatus.completed) _updateZoomLevel();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(ZoomablePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    final layoutChanged =
        old.fit != widget.fit ||
        old.viewport != widget.viewport ||
        old.source.id != widget.source.id ||
        !listEquals(old.pages, widget.pages);
    if (layoutChanged) {
      _reset();
      _resolve();
    } else if (old.isCurrent && !widget.isCurrent) {
      _reset();
    } else if (!old.isCurrent && widget.isCurrent) {
      _reportLock(force: true);
    }
  }

  @override
  void dispose() {
    _unlisten();
    _anim.dispose();
    _tc.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Image resolution

  double get _dpr => MediaQuery.devicePixelRatioOf(context);

  /// The provider for the [slot]-th page of this unit.
  ImageProvider _provider(int slot, {int zoom = 1}) => unitPageProvider(
    widget.source,
    widget.pages[slot],
    widget.pages.length,
    widget.fit,
    widget.viewport,
    _dpr,
    zoom: zoom,
  );

  bool get _ready => _sizes.isNotEmpty && _sizes.every((s) => s != null);

  void _resolve() {
    final config = createLocalImageConfiguration(context);
    final streams = [
      for (var i = 0; i < widget.pages.length; i++)
        _provider(i).resolve(config),
    ];
    if (_sameStreams(streams)) return;
    _unlisten();
    _sizes = List.filled(streams.length, null);
    _error = null;
    for (var i = 0; i < streams.length; i++) {
      final listener = ImageStreamListener(
        (info, _) => _onImage(i, info),
        onError: _onImageError,
      );
      _streams.add(streams[i]..addListener(listener));
      _listeners.add(listener);
    }
  }

  bool _sameStreams(List<ImageStream> streams) {
    if (streams.length != _streams.length) return false;
    for (var i = 0; i < streams.length; i++) {
      if (streams[i].key != _streams[i].key) return false;
    }
    return true;
  }

  void _unlisten() {
    for (var i = 0; i < _streams.length; i++) {
      _streams[i].removeListener(_listeners[i]);
    }
    _streams.clear();
    _listeners.clear();
  }

  void _onImage(int slot, ImageInfo info) {
    final size = Size(
      info.image.width.toDouble(),
      info.image.height.toDouble(),
    );
    info.dispose();
    if (!mounted || slot >= _sizes.length) return;
    setState(() => _sizes = [..._sizes]..[slot] = size);
    if (_ready) _reportLock(force: true);
  }

  void _onImageError(Object error, StackTrace? _) {
    if (mounted) setState(() => _error = error);
  }

  // ---------------------------------------------------------------------------
  // Geometry

  /// Logical size of each page at scale 1. Pages in a spread share a common
  /// height (except at original size, where each keeps its own).
  List<Size> get _slots {
    final sizes = [for (final s in _sizes) s!];
    if (widget.fit == FitMode.original) {
      return [for (final s in sizes) s / _dpr];
    }
    final v = widget.viewport;
    final ratios = [for (final s in sizes) s.width / s.height];
    final total = ratios.fold(0.0, (a, b) => a + b);
    final height = switch (widget.fit) {
      FitMode.screen => v.width / v.height > total ? v.height : v.width / total,
      FitMode.width => v.width / total,
      _ => v.height,
    };
    return [for (final r in ratios) Size(height * r, height)];
  }

  /// Logical size of the whole unit at scale 1.
  Size get _base {
    final slots = _slots;
    return Size(
      slots.fold(0.0, (w, s) => w + s.width),
      slots.fold(0.0, (h, s) => math.max(h, s.height)),
    );
  }

  /// The pannable canvas: the page, padded to at least the viewport size.
  Size get _content {
    final b = _base;
    final v = widget.viewport;
    return Size(math.max(b.width, v.width), math.max(b.height, v.height));
  }

  double get _scale => _tc.value.getMaxScaleOnAxis();

  /// Where the transform is heading (the animation target while animating).
  Matrix4 get _targetValue => _anim.isAnimating ? _tween!.end! : _tc.value;

  /// A transform with scale [s] and translation clamped to the content.
  Matrix4 _matrix(double s, double tx, double ty) {
    final c = _content;
    final v = widget.viewport;
    final x = clampDouble(tx, math.min(0.0, v.width - c.width * s), 0.0);
    final y = clampDouble(ty, math.min(0.0, v.height - c.height * s), 0.0);
    return Matrix4.diagonal3Values(s, s, 1)..setTranslationRaw(x, y, 0);
  }

  void _animateTo(Matrix4 target) {
    _tween = Matrix4Tween(begin: _tc.value, end: target);
    _anim.forward(from: 0);
  }

  void _reset() {
    _anim.stop();
    _tc.value = Matrix4.identity();
    _zoomLevel = 1;
  }

  void _onTransform() => _reportLock();

  void _reportLock({bool force = false}) {
    if (!_ready) return;
    final locked =
        _scale > 1.01 || _content.width > widget.viewport.width + 0.5;
    if (locked == _locked && !force) return;
    _locked = locked;
    // May be reached during build (didUpdateWidget), so notify the reader
    // after the frame instead of making it setState mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isCurrent) widget.onLockChanged(_locked);
    });
  }

  /// Re-decode at higher resolution once the user settles on a zoom level.
  void _updateZoomLevel() {
    final s = _scale;
    final level = s < 1.5 ? 1 : (s < 3 ? 2 : 4);
    if (level != _zoomLevel && mounted) setState(() => _zoomLevel = level);
  }

  // ---------------------------------------------------------------------------
  // Commands (called by the reader)

  /// Scrolls vertically by [dy] logical pixels. Returns false if the page
  /// is already at that edge (so the reader should turn the page instead).
  bool scrollBy(double dy, {bool animate = false}) {
    if (!_ready) return false;
    final m = _targetValue;
    final t = m.getTranslation();
    final target = _matrix(m.getMaxScaleOnAxis(), t.x, t.y - dy);
    if ((target.getTranslation().y - t.y).abs() < 0.5) return false;
    if (animate) {
      _animateTo(target);
    } else {
      _anim.stop();
      _tc.value = target;
    }
    return true;
  }

  /// Zooms by [factor] around the viewport centre.
  void zoomBy(double factor) {
    final v = widget.viewport;
    _zoomAround(v.center(Offset.zero), _scale * factor);
  }

  void resetZoom() {
    if (!_ready) return;
    _animateTo(Matrix4.identity());
  }

  /// Double-tap behaviour: zoom into [globalPosition], or back out.
  void toggleZoomAt(Offset globalPosition) {
    if (!_ready) return;
    final box = context.findRenderObject()! as RenderBox;
    final p = box.globalToLocal(globalPosition);
    _zoomAround(p, _scale > 1.01 ? 1 : _doubleTapScale);
  }

  void _zoomAround(Offset focal, double newScale) {
    if (!_ready) return;
    final s = _scale;
    final t = _tc.value.getTranslation();
    final ns = clampDouble(newScale, 1.0, _maxScale);
    // Keep the content point under [focal] fixed while scaling.
    final cx = (focal.dx - t.x) / s;
    final cy = (focal.dy - t.y) / s;
    _animateTo(_matrix(ns, focal.dx - cx * ns, focal.dy - cy * ns));
  }

  // ---------------------------------------------------------------------------
  // Input

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    // Ctrl+wheel: let InteractiveViewer zoom.
    if (HardwareKeyboard.instance.isControlPressed) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final dy = (e as PointerScrollEvent).scrollDelta.dy;
      if (dy == 0) return;
      final now = DateTime.now();
      if (scrollBy(dy)) {
        _lastScrollMove = now;
        return;
      }
      // Just hit the edge while scrolling: pause there instead of flipping
      // straight through. The next deliberate scroll turns the page.
      if (now.difference(_lastScrollMove) < const Duration(milliseconds: 400)) {
        _lastScrollMove = now;
        return;
      }
      widget.onScrollPastEdge(dy > 0 ? 1 : -1);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Text(
          "Couldn't load page ${widget.pages.map((p) => p + 1).join('–')}"
          '\n$_error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
    if (!_ready) {
      // Still a scroll target while loading.
      return Listener(
        onPointerSignal: _onPointerSignal,
        child: const SizedBox.expand(child: _DelayedSpinner()),
      );
    }
    return InteractiveViewer(
      transformationController: _tc,
      constrained: false,
      minScale: 1,
      maxScale: _maxScale,
      onInteractionStart: (_) => _anim.stop(),
      onInteractionEnd: (_) => _updateZoomLevel(),
      child: Listener(
        onPointerSignal: _onPointerSignal,
        child: _pageDragDetector(
          SizedBox.fromSize(
            size: _content,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, slot) in _slots.indexed)
                    SizedBox.fromSize(
                      size: slot,
                      child: Image(
                        image: _provider(i, zoom: _zoomLevel),
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (context, error, _) => const SizedBox(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageDragDetector(Widget child) {
    if (widget.onPageDrag == null || _locked) return child;
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque, // margins beside the page too
      gestures: {
        _PageDragRecognizer:
            GestureRecognizerFactoryWithHandlers<_PageDragRecognizer>(
              () => _PageDragRecognizer(debugOwner: this),
              (r) => r
                ..onStart = (d) {
                  _pageDrag = widget.onPageDrag?.call(d);
                }
                ..onUpdate = (d) {
                  _pageDrag?.update(d);
                }
                ..onEnd = (d) {
                  _pageDrag?.end(d);
                  _pageDrag = null;
                }
                ..onCancel = () {
                  _pageDrag?.cancel();
                  _pageDrag = null;
                },
            ),
      },
      child: child,
    );
  }
}

/// A one-finger horizontal drag (touch/stylus only); gives up if a second
/// finger lands before it has won, so pinches reach the zoom recognizer.
class _PageDragRecognizer extends HorizontalDragGestureRecognizer {
  _PageDragRecognizer({super.debugOwner})
    : super(
        supportedDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
          PointerDeviceKind.unknown,
        },
      );

  int _pointers = 0;
  bool _won = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    if (++_pointers > 1 && !_won) resolve(GestureDisposition.rejected);
  }

  @override
  void acceptGesture(int pointer) {
    _won = true;
    super.acceptGesture(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _pointers = 0;
    _won = false;
    super.didStopTrackingLastPointer(pointer);
  }
}

/// A progress indicator that only appears if loading takes noticeably long,
/// so fast page turns don't flash a spinner.
class _DelayedSpinner extends StatefulWidget {
  const _DelayedSpinner();

  @override
  State<_DelayedSpinner> createState() => _DelayedSpinnerState();
}

class _DelayedSpinnerState extends State<_DelayedSpinner> {
  bool _visible = false;
  late final Timer _timer = Timer(const Duration(milliseconds: 400), () {
    if (mounted) setState(() => _visible = true);
  });

  @override
  void initState() {
    super.initState();
    _timer; // start
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _visible
      ? const Center(child: CircularProgressIndicator(color: Colors.white54))
      : const SizedBox();
}
