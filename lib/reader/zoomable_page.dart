import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/sources/page_source.dart';
import 'fit_mode.dart';

/// One page in the reader: lays the image out for a [FitMode], and supports
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
    required this.index,
    required this.fit,
    required this.viewport,
    required this.isCurrent,
    required this.onLockChanged,
    required this.onScrollPastEdge,
  });

  final PageSource source;
  final int index;
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

  ImageStream? _stream;
  late final _listener = ImageStreamListener(_onImage, onError: _onImageError);
  Size? _imageSize;
  Object? _error;
  int _zoomLevel = 1;
  bool _locked = false;
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
        old.index != widget.index;
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
    _stream?.removeListener(_listener);
    _anim.dispose();
    _tc.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Image resolution

  double get _dpr => MediaQuery.devicePixelRatioOf(context);

  ImageProvider _provider({int zoom = 1}) => pageProvider(
    widget.source,
    widget.index,
    widget.fit,
    widget.viewport,
    _dpr,
    zoom: zoom,
  );

  void _resolve() {
    final stream = _provider().resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  void _onImage(ImageInfo info, bool _) {
    final size = Size(
      info.image.width.toDouble(),
      info.image.height.toDouble(),
    );
    info.dispose();
    if (!mounted) return;
    setState(() {
      _imageSize = size;
      _error = null;
    });
    _reportLock(force: true);
  }

  void _onImageError(Object error, StackTrace? _) {
    if (mounted) setState(() => _error = error);
  }

  // ---------------------------------------------------------------------------
  // Geometry

  /// Logical size of the page image at scale 1.
  Size get _base {
    final img = _imageSize!;
    final v = widget.viewport;
    final ar = img.width / img.height;
    return switch (widget.fit) {
      FitMode.screen =>
        v.width / v.height > ar
            ? Size(v.height * ar, v.height)
            : Size(v.width, v.width / ar),
      FitMode.width => Size(v.width, v.width / ar),
      FitMode.height => Size(v.height * ar, v.height),
      FitMode.original => img / _dpr,
    };
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
    if (_imageSize == null) return;
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
    if (_imageSize == null) return false;
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
    if (_imageSize == null) return;
    _animateTo(Matrix4.identity());
  }

  /// Double-tap behaviour: zoom into [globalPosition], or back out.
  void toggleZoomAt(Offset globalPosition) {
    if (_imageSize == null) return;
    final box = context.findRenderObject()! as RenderBox;
    final p = box.globalToLocal(globalPosition);
    _zoomAround(p, _scale > 1.01 ? 1 : _doubleTapScale);
  }

  void _zoomAround(Offset focal, double newScale) {
    if (_imageSize == null) return;
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
          "Couldn't load page ${widget.index + 1}\n$_error",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
    if (_imageSize == null) {
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
        child: SizedBox.fromSize(
          size: _content,
          child: Center(
            child: SizedBox.fromSize(
              size: _base,
              child: Image(
                image: _provider(zoom: _zoomLevel),
                fit: BoxFit.fill,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, _) => const SizedBox(),
              ),
            ),
          ),
        ),
      ),
    );
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
