import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'state.dart';

/// One shared, muted, looping player per bundled video. Dashboard tiles, the
/// camera preview and the fullscreen viewer all show the same controller, so
/// each stream is only downloaded/decoded once.
class FeedHub {
  FeedHub._();
  static final FeedHub instance = FeedHub._();

  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, Future<void>> _ready = {};

  VideoPlayerController controller(String url) {
    final existing = _controllers[url];
    if (existing != null) return existing;
    final c = VideoPlayerController.asset(
      url,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controllers[url] = c;
    _ready[url] = _start(c);
    return c;
  }

  Future<void> _start(VideoPlayerController c) async {
    await c.initialize();
    await c.setVolume(0);
    await c.setLooping(true);
    await c.play();
  }

  Future<void> ready(String url) {
    controller(url);
    return _ready[url]!;
  }

  /// Throw away a (failed) controller so the next use reconnects.
  void reset(String url) {
    final c = _controllers.remove(url);
    _ready.remove(url);
    c?.dispose();
  }

  /// Current playback position of a feed (zero if it is not playing).
  Duration positionOf(String url) {
    final c = _controllers[url];
    if (c == null || !c.value.isInitialized) return Duration.zero;
    return c.value.position;
  }

  void disposeAll() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _ready.clear();
  }

  void pauseAll() {
    for (final c in _controllers.values) {
      if (c.value.isInitialized) c.pause();
    }
  }

  void resumeAll() {
    for (final c in _controllers.values) {
      if (c.value.isInitialized) c.play();
    }
  }
}

/// Plays a camera's feed. Shows the thumbnail while loading and a retry
/// button when the stream cannot be played.
class LiveVideo extends StatefulWidget {
  final Camera cam;
  final BoxFit fit;
  const LiveVideo({super.key, required this.cam, this.fit = BoxFit.cover});

  @override
  State<LiveVideo> createState() => _LiveVideoState();
}

class _LiveVideoState extends State<LiveVideo> {
  int _attempt = 0;

  Widget _still({bool spinner = false}) {
    final thumb = widget.cam.thumbAsset;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0xFF111A29)),
        Image.asset(thumb,
            fit: widget.fit, errorBuilder: (c, e, s) => const SizedBox()),
        if (spinner)
          const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
            ),
          ),
      ],
    );
  }

  Widget _failed(String url) => Container(
        color: const Color(0xFF111A29),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFF7A879C), size: 28),
            const SizedBox(height: 4),
            const Text('Stream unavailable',
                style: TextStyle(color: Color(0xFF7A879C), fontSize: 11)),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {
                FeedHub.instance.reset(url);
                setState(() => _attempt++);
              },
              child: const Text('Tap to retry',
                  style: TextStyle(
                      color: Color(0xFF6FA8FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cam = widget.cam;
    final url = cam.feedAsset;
    if (cam.restarting) {
      // Drop the old player so the feed starts fresh after the restart.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => FeedHub.instance.reset(url));
      return const RestartingView();
    }
    if (!cam.online) return const OfflineView();
    final hub = FeedHub.instance;
    return FutureBuilder<void>(
      key: ValueKey('$url#$_attempt'),
      future: hub.ready(url),
      builder: (context, snap) {
        if (snap.hasError) return _failed(url);
        if (snap.connectionState != ConnectionState.done) {
          return _still(spinner: true);
        }
        final c = hub.controller(url);
        return ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: c,
          builder: (context, v, child) {
            if (v.hasError) return _failed(url);
            if (!v.isInitialized) return _still(spinner: true);
            return ClipRect(
              child: SizedBox.expand(
                child: FittedBox(
                  fit: widget.fit,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: v.size.width,
                    height: v.size.height,
                    child: VideoPlayer(c),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class RestartingView extends StatelessWidget {
  const RestartingView({super.key});
  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF111A29),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
            ),
            SizedBox(height: 10),
            Text('Restarting camera…',
                style: TextStyle(color: Color(0xFF7A879C), fontSize: 11)),
          ],
        ),
      );
}

class NoVideoView extends StatelessWidget {
  const NoVideoView({super.key});
  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF111A29),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_outlined, color: Color(0xFF7A879C), size: 28),
            SizedBox(height: 6),
            Text('No feed available',
                style: TextStyle(color: Color(0xFF7A879C), fontSize: 11)),
          ],
        ),
      );
}

class OfflineView extends StatelessWidget {
  const OfflineView({super.key});
  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF111A29),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_outlined, color: Color(0xFF7A879C), size: 30),
            SizedBox(height: 6),
            Text('Camera offline',
                style: TextStyle(color: Color(0xFF7A879C), fontSize: 11)),
          ],
        ),
      );
}

/// Text that follows the clock.
class ClockText extends StatelessWidget {
  final String Function(DateTime) format;
  final TextStyle? style;
  const ClockText({super.key, required this.format, this.style});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DateTime>(
        valueListenable: app.clock,
        builder: (context, t, child) => Text(format(t), style: style),
      );
}

/// "CH 01 · 07:42:00" chip shown over a video.
class CamStamp extends StatelessWidget {
  final String channel;
  const CamStamp(this.channel, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(6)),
        child: ValueListenableBuilder<DateTime>(
          valueListenable: app.clock,
          builder: (context, t, child) => Text(
            '$channel · ${fmtClock(t)}',
            style: const TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
      );
}

class LiveDot extends StatelessWidget {
  final bool on;
  const LiveDot({super.key, this.on = true});
  @override
  Widget build(BuildContext context) => Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
          color: on ? const Color(0xFF3DDC84) : const Color(0xFF7A879C),
          shape: BoxShape.circle));
}
