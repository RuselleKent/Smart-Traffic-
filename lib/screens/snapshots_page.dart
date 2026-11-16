import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Takes a snapshot on the server and offers a shortcut to the gallery.
Future<void> captureSnapshot(Camera cam) async {
  app.toast('Capturing…');
  final s = await app.takeSnapshot(cam);
  if (s == null) return;
  final m = app.messengerKey.currentState;
  m
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text('Snapshot saved · ${cam.channel} · ${fmtClock(s.time)}'),
      action: SnackBarAction(
        label: 'View',
        onPressed: () {
          final ctx = app.messengerKey.currentContext;
          if (ctx != null) showSnapshot(ctx, s);
        },
      ),
    ));
}

void showSnapshot(BuildContext context, Snapshot s) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.navy,
      insetPadding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
            child: Row(children: [
              Expanded(
                child: Text('${s.cameraName}\n${fmtDate(s.time)} · ${fmtTime12(s.time)}',
                    style: t(12, w: FontWeight.w600, c: Colors.white, h: 1.4)),
              ),
              IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx)),
            ]),
          ),
          Flexible(
            child: InteractiveViewer(
              child: Image.asset(s.asset,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, st) => const Padding(
                        padding: EdgeInsets.all(40),
                        child: Text('Could not load the image',
                            style: TextStyle(color: Colors.white70)),
                      )),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: OutlineBtn('Copy details', icon: Icons.copy_outlined, onTap: () async {
                  await Clipboard.setData(ClipboardData(text: '${s.cameraName} · ${fmtDate(s.time)} ${fmtTime12(s.time)}'));
                  app.toast('Details copied');
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryBtn('Delete', icon: Icons.delete_outline, onTap: () {
                  Navigator.pop(ctx);
                  app.deleteSnapshot(s);
                }),
              ),
            ]),
          ),
        ],
      ),
    ),
  );
}

class SnapshotsPage extends StatefulWidget {
  const SnapshotsPage({super.key});
  @override
  State<SnapshotsPage> createState() => _SnapshotsPageState();
}

class _SnapshotsPageState extends State<SnapshotsPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    app.loadSnapshots().then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Frame(
        child: ColoredBox(
          color: AppColors.bg,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(children: [
                    IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context)),
                    Text('Snapshots', style: t(18, w: FontWeight.w700)),
                  ]),
                ),
                Expanded(
                  child: ListenableBuilder(
                    listenable: app,
                    builder: (context, child) {
                      final list = app.snapshots;
                      if (_loading && list.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (list.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(30),
                            child: Text(
                                'No snapshots yet.\nOpen a camera and tap the camera button to capture one.',
                                textAlign: TextAlign.center,
                                style: t(13, c: AppColors.muted, h: 1.5)),
                          ),
                        );
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.15),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final s = list[i];
                          return GestureDetector(
                            onTap: () => showSnapshot(context, s),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(fit: StackFit.expand, children: [
                                Image.asset(s.asset,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, st) =>
                                        Container(color: AppColors.navy)),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    color: Colors.black54,
                                    padding: const EdgeInsets.all(6),
                                    child: Text(
                                        '${s.cameraName}\n${fmtShortDate(s.time)} · ${fmtTime12(s.time)}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: t(10, c: Colors.white, h: 1.3)),
                                  ),
                                ),
                              ]),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
