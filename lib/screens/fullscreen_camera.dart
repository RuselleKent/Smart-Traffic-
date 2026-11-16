import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../feed.dart';
import '../state.dart';
import '../theme.dart';
import 'snapshots_page.dart';

/// Fullscreen live viewer. Tap the video to show/hide the controls.
class FullscreenCamera extends StatefulWidget {
  final String cameraId;
  const FullscreenCamera({super.key, required this.cameraId});
  @override
  State<FullscreenCamera> createState() => _FullscreenCameraState();
}

class _FullscreenCameraState extends State<FullscreenCamera> {
  late int _index;
  bool _chrome = true;

  @override
  void initState() {
    super.initState();
    _index = app.cameras.indexWhere((c) => c.id == widget.cameraId);
    if (_index < 0) _index = 0;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _step(int d) {
    final n = app.cameras.length;
    if (n == 0) return;
    setState(() => _index = (_index + d + n) % n);
  }

  Widget _round(IconData icon, VoidCallback? onTap, {double size = 26}) =>
      Material(
        color: Colors.white.withValues(alpha: 0.16),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: Colors.white, size: size),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: app, builder: (context, _) => _body(context));
  }

  Widget _body(BuildContext context) {
    if (app.cameras.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(backgroundColor: Colors.black);
    }
    if (_index >= app.cameras.length) _index = 0;
    final cam = app.cameras[_index];
    final ctrl = cam.online ? FeedHub.instance.controller(cam.feedAsset) : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _chrome = !_chrome),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: LiveVideo(cam: cam, fit: BoxFit.cover),
              ),
            ),
            if (_chrome) ...[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xCC000000), Color(0x00000000)],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 6, 14, 18),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cam.name,
                                    style: t(15, w: FontWeight.w700, c: Colors.white)),
                                Text('${cam.channel} · ${cam.direction}',
                                    style: t(11, c: const Color(0xFFD0D8E4))),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: cam.online
                                    ? AppColors.red
                                    : const Color(0xFF5B677A),
                                borderRadius: BorderRadius.circular(6)),
                            child: Text(cam.statusLabel.toUpperCase(),
                                style: t(10, w: FontWeight.w700, c: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xCC000000), Color(0x00000000)],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 30, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              CamStamp(cam.channel),
                              ListenableBuilder(
                                listenable: app,
                                builder: (context, child) => Text(
                                    app.quality,
                                    style: t(11, c: const Color(0xFFD0D8E4))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _round(Icons.skip_previous_rounded, () => _step(-1)),
                              const SizedBox(width: 18),
                              if (ctrl == null)
                                _round(Icons.play_arrow_rounded, null, size: 32)
                              else
                                ValueListenableBuilder<VideoPlayerValue>(
                                  valueListenable: ctrl,
                                  builder: (context, v, child) => _round(
                                    v.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    !cam.online || !v.isInitialized
                                        ? null
                                        : () => v.isPlaying
                                            ? ctrl.pause()
                                            : ctrl.play(),
                                    size: 32,
                                  ),
                                ),
                              const SizedBox(width: 18),
                              _round(Icons.photo_camera_outlined,
                                  () => captureSnapshot(cam)),
                              const SizedBox(width: 18),
                              _round(Icons.skip_next_rounded, () => _step(1)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

void openCamera(BuildContext context, String cameraId) {
  Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FullscreenCamera(cameraId: cameraId)));
}
