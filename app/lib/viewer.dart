import 'package:material_ui/material_ui.dart';

import 'ui.dart';

/// Full-screen photos: swipe between them, pinch or double-tap to zoom,
/// and close with the X or the phone's back gesture.
Future<void> openViewer(
  BuildContext context,
  List<String> images, {
  int start = 0,
}) => Navigator.of(context).push(
  PageRouteBuilder(
    opaque: true,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, _, _) => ImageViewer(images: images, start: start),
    transitionsBuilder: (_, a, _, child) =>
        FadeTransition(opacity: a, child: child),
  ),
);

class ImageViewer extends StatefulWidget {
  final List<String> images;
  final int start;
  const ImageViewer({super.key, required this.images, this.start = 0});
  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  late final _pages = PageController(initialPage: widget.start);
  late int _index = widget.start;
  bool _zoomed = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.images.length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
            itemCount: n,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _ZoomImage(
              url: widget.images[i],
              onZoom: (z) => setState(() => _zoomed = z),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton.filled(
                    tooltip: 'Back',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                  const Spacer(),
                  if (n > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_index + 1} / $n',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (n > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < n; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _index ? 18 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _index ? Colors.white : Colors.white38,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ZoomImage extends StatefulWidget {
  final String url;
  final ValueChanged<bool> onZoom;
  const _ZoomImage({required this.url, required this.onZoom});
  @override
  State<_ZoomImage> createState() => _ZoomImageState();
}

class _ZoomImageState extends State<_ZoomImage> {
  final _t = TransformationController();
  TapDownDetails? _tap;

  void _toggle() {
    if (_t.value != Matrix4.identity()) {
      _t.value = Matrix4.identity();
      widget.onZoom(false);
    } else {
      final p = _tap?.localPosition ?? Offset.zero;
      _t.value = Matrix4.identity()
        ..translateByDouble(-p.dx * 1.5, -p.dy * 1.5, 0, 1)
        ..scaleByDouble(2.5, 2.5, 1, 1);
      widget.onZoom(true);
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onDoubleTapDown: (d) => _tap = d,
    onDoubleTap: _toggle,
    child: InteractiveViewer(
      transformationController: _t,
      minScale: 1,
      maxScale: 5,
      onInteractionEnd: (_) =>
          widget.onZoom(_t.value.getMaxScaleOnAxis() > 1.01),
      child: Center(child: DealImage(widget.url, fit: BoxFit.contain)),
    ),
  );
}
