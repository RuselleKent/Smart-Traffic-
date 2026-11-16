import 'package:flutter/material.dart';
import '../feed.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'fullscreen_camera.dart';
import 'snapshots_page.dart';

class CamerasScreen extends StatefulWidget {
  const CamerasScreen({super.key});
  @override
  State<CamerasScreen> createState() => _CamerasScreenState();
}

class _CamerasScreenState extends State<CamerasScreen> {
  int _filter = 0;
  String _query = '';
  String _direction = 'All';

  List<Camera> _visible() {
    final q = _query.trim().toLowerCase();
    return app.cameras.where((c) {
      if (_filter == 1 && !c.online) return false;
      if (_filter == 2 && c.online) return false;
      if (_direction != 'All' && c.direction != _direction) return false;
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          c.direction.toLowerCase().contains(q) ||
          c.channel.toLowerCase().contains(q) ||
          c.location.toLowerCase().contains(q);
    }).toList();
  }

  void _filterSheet() {
    showAppSheet(
      context,
      (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter by direction', style: t(16, w: FontWeight.w700)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in ['All', ...kDirections])
                  ChoiceChip(
                    label: Text(d, style: t(12, w: FontWeight.w600)),
                    selected: _direction == d,
                    selectedColor: AppColors.blueSoft,
                    onSelected: (_) {
                      setState(() => _direction = d);
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(Camera c) async {
    final ctl = TextEditingController(text: c.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Rename camera', style: t(16, w: FontWeight.w700)),
        content: TextField(controller: ctl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: t(13, w: FontWeight.w600, c: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Save', style: t(13, w: FontWeight.w600, c: AppColors.blue)),
          ),
        ],
      ),
    );
    if (ok == true) app.renameCamera(c, ctl.text);
    ctl.dispose();
  }

  Future<void> _restart(Camera c) async {
    final ok = await showInfo(
        context,
        'Restart ${c.channel}?',
        '${c.name} will go offline for about 10 seconds while it restarts, then reconnect on its own.',
        confirm: 'Restart');
    if (ok == true) app.restartCamera(c);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, child) {
        final total = app.cameras.length;
        final online = app.onlineCount;
        final sel = app.selected;
        final list = _visible();
        return RefreshIndicator(
          onRefresh: () => app.refresh(force: true),
          child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            const PageHeader(
                title: 'Cameras', subtitle: 'Live feeds from the road network'),
            Row(children: [
              _Count('$total', 'Total cameras', AppColors.blueSoft),
              const SizedBox(width: 10),
              _Count('$online', 'Online', AppColors.mint),
              const SizedBox(width: 10),
              _Count('${total - online}', 'Offline', AppColors.grayChip),
            ]),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border)),
              child: Row(children: [
                const Icon(Icons.search, color: AppColors.muted, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: t(13),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Search camera or location',
                      hintStyle: t(13, c: AppColors.muted),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _filterSheet,
                  child: Icon(Icons.tune,
                      color: _direction == 'All' ? AppColors.ink : AppColors.blue,
                      size: 22),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            SegmentedTabs(
              labels: ['All cameras ($total)', 'Online ($online)', 'Offline (${total - online})'],
              index: _filter,
              blueText: true,
              onChanged: (i) => setState(() => _filter = i),
            ),
            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Live preview', style: t(17, w: FontWeight.w700)),
                Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const SnapshotsPage())),
                    child: Text('Snapshots',
                        style: t(12, w: FontWeight.w600, c: AppColors.blue)),
                  ),
                  if (sel != null) ...[
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => openCamera(context, sel.id),
                      child: Text('Fullscreen ↗',
                          style: t(12, w: FontWeight.w600, c: AppColors.blue)),
                    ),
                  ],
                ]),
              ],
            ),
            const SizedBox(height: 14),
            if (sel == null)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  child: Center(
                      child: Text('No cameras are connected.',
                          style: t(12.5, c: AppColors.muted))),
                ),
              )
            else ...[
            GestureDetector(
              onTap: () => openCamera(context, sel.id),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: AppColors.navy,
                  child: Column(children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          LiveVideo(cam: sel),
                          Positioned(left: 8, top: 8, child: CamStamp(sel.channel)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sel.name,
                              style: t(15, w: FontWeight.w700, c: Colors.white)),
                          const SizedBox(height: 8),
                          Row(children: [
                            LiveDot(on: sel.online),
                            const SizedBox(width: 6),
                            Text(sel.statusLabel,
                                style: t(11,
                                    w: FontWeight.w600,
                                    c: sel.online
                                        ? const Color(0xFF3DDC84)
                                        : const Color(0xFF7A879C))),
                            const Spacer(),
                            Flexible(
                              child: Text('${app.quality} · ${sel.direction}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t(11, c: const Color(0xFFB6C2D6))),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(sel.location,
                            style: t(15, w: FontWeight.w700)),
                      ),
                      sel.online
                          ? const Pill('Healthy',
                              bg: AppColors.mint, fg: AppColors.greenDark)
                          : Pill(sel.restarting ? 'Restarting' : 'Offline',
                              bg: AppColors.grayChip, fg: AppColors.muted),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    _Spec('Resolution', app.resolutionText),
                    _Spec('Direction', sel.direction),
                    _Spec('Uptime', sel.online ? sel.uptime : '—'),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: OutlineBtn('Snapshot',
                          icon: Icons.photo_camera_outlined,
                          onTap: () => captureSnapshot(sel)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryBtn(
                          sel.restarting ? 'Restarting…' : 'Restart camera',
                          icon: Icons.restart_alt,
                          onTap: sel.online ? () => _restart(sel) : null),
                    ),
                  ]),
                ],
              ),
            ),
            ],
            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('All cameras', style: t(17, w: FontWeight.w700)),
                if (sel != null)
                  GestureDetector(
                    onTap: () => _rename(sel),
                    child: Text('Rename selected',
                        style: t(12, w: FontWeight.w600, c: AppColors.blue)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: Text('No cameras match your filters',
                        style: t(13, c: AppColors.muted))),
              ),
            for (final c in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CamRow(
                  cam: c,
                  selected: c.id == sel?.id,
                  onTap: () => app.select(c),
                  onMenu: (v) {
                    if (v == 'rename') _rename(c);
                    if (v == 'restart') _restart(c);
                    if (v == 'snapshot') captureSnapshot(c);
                    if (v == 'fullscreen') openCamera(context, c.id);
                  },
                ),
              ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                '${online == total ? 'All $total feeds connected' : '$online of $total feeds connected'} · Updated ${app.lastSync == null ? '—' : fmtTime12(app.lastSync!)}',
                style: t(11, c: AppColors.muted),
              ),
            ),
          ],
        ));
      },
    );
  }
}

class _CamRow extends StatelessWidget {
  final Camera cam;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<String> onMenu;
  const _CamRow(
      {required this.cam,
      required this.selected,
      required this.onTap,
      required this.onMenu});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? AppColors.blue : AppColors.border,
              width: selected ? 1.5 : 1),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 78,
              height: 58,
              child: cam.online
                  ? Image.asset(cam.thumbAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, st) => Container(
                          color: const Color(0xFF111A29),
                          child: const Icon(Icons.videocam_outlined,
                              color: Color(0xFF7A879C))))
                  : Container(
                      color: const Color(0xFF111A29),
                      child: Icon(
                          cam.restarting
                              ? Icons.restart_alt
                              : Icons.videocam_off_outlined,
                          color: const Color(0xFF7A879C))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cam.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t(13, w: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${cam.channel} · ${cam.location}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t(11, c: AppColors.muted)),
                const SizedBox(height: 5),
                Row(children: [
                  Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: cam.online ? AppColors.green : AppColors.muted,
                          shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(cam.online ? 'Live · ${app.quality}' : cam.statusLabel,
                      style: t(11,
                          w: FontWeight.w600,
                          c: cam.online ? AppColors.greenDark : AppColors.muted)),
                ]),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.ink),
            onSelected: onMenu,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'fullscreen', child: Text('Open fullscreen')),
              const PopupMenuItem(value: 'snapshot', child: Text('Take snapshot')),
              const PopupMenuItem(value: 'rename', child: Text('Rename')),
              const PopupMenuItem(value: 'restart', child: Text('Restart camera')),
            ],
          ),
        ]),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  final String n, label;
  final Color bg;
  const _Count(this.n, this.label, this.bg);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n, style: t(26, w: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(label, style: t(11, c: AppColors.muted)),
            ],
          ),
        ),
      );
}

class _Spec extends StatelessWidget {
  final String k, v;
  const _Spec(this.k, this.v);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k, style: t(10.5, c: AppColors.muted)),
            const SizedBox(height: 4),
            Text(v,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t(13, w: FontWeight.w700)),
          ],
        ),
      );
}
