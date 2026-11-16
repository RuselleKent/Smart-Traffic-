import 'package:flutter/material.dart';
import '../feed.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'fullscreen_camera.dart';
import 'map_page.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, child) {
        final cams = app.cameras.take(4).toList();
        final vPct = app.vehiclesDeltaPct;
        final sPct = app.speedDeltaPct;
        String delta(int p) => '${p >= 0 ? '+' : '−'} ${p.abs()}% vs yesterday';
        return RefreshIndicator(
          onRefresh: () => app.refresh(force: true),
          child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            const PageHeader(
                title: 'Dashboard', subtitle: 'Real-time traffic overview'),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _Stat(
                      color: AppColors.cyan,
                      iconBg: AppColors.blue,
                      icon: Icons.directions_car_outlined,
                      label: 'Total vehicles\n(Today)',
                      value: fmtInt(app.vehiclesToday),
                      foot: delta(vPct),
                      footColor: vPct >= 0 ? AppColors.greenDark : AppColors.red,
                      onTap: () => app.tab.value = 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Stat(
                      color: AppColors.mint,
                      iconBg: AppColors.green,
                      icon: Icons.speed,
                      label: 'Avg. Speed',
                      value: app.speedText(app.speedKmh),
                      foot: delta(sPct),
                      footColor: sPct >= 0 ? AppColors.greenDark : AppColors.red,
                      onTap: () => app.tab.value = 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _Stat(
                      color: AppColors.sand,
                      iconBg: AppColors.yellow,
                      icon: Icons.access_time,
                      label: 'Congestion level',
                      value: app.congestionLabel,
                      foot: 'Main intersection',
                      footColor: AppColors.muted,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const MapPage(focusZoneId: 'B'))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Stat(
                      color: AppColors.rose,
                      iconBg: AppColors.red,
                      icon: Icons.warning_amber_rounded,
                      label: 'Active alerts',
                      value: '${app.activeCount}',
                      foot: app.activeCount == 0
                          ? 'All clear'
                          : 'Requires attention',
                      footColor: AppColors.muted,
                      onTap: () => app.tab.value = 3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Live Camera Feeds', style: t(17, w: FontWeight.w700)),
                GestureDetector(
                  onTap: () => app.tab.value = 1,
                  child: Text('View all →',
                      style: t(12, w: FontWeight.w600, c: AppColors.blue)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (cams.isEmpty)
              AppCard(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text('No cameras are connected.',
                        style: t(12.5, c: AppColors.muted)),
                  ),
                ),
              )
            else
            LayoutBuilder(builder: (context, c) {
              final w = (c.maxWidth - 12) / 2;
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: w / (w * 0.62 + 78),
                children: [for (final cam in cams) _FeedTile(cam: cam)],
              );
            }),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Traffic Map', style: t(17, w: FontWeight.w700)),
                GestureDetector(
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const MapPage())),
                  child: Text('Expand +',
                      style: t(12, w: FontWeight.w600, c: AppColors.blue)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _MiniMapCard(),
          ],
        ));
      },
    );
  }
}

class _MiniMapCard extends StatelessWidget {
  const _MiniMapCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 260,
              width: double.infinity,
              child: ZoneMap(
                interactive: false,
                onMapTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const MapPage())),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const MapLegend(),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final Color color, iconBg, footColor;
  final IconData icon;
  final String label, value, foot;
  final VoidCallback onTap;
  const _Stat({
    required this.color,
    required this.iconBg,
    required this.icon,
    required this.label,
    required this.value,
    required this.foot,
    required this.footColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 138),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                      color: iconBg, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(label,
                        style: t(11, c: const Color(0xFF3F4B63), h: 1.25))),
              ]),
              const SizedBox(height: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: t(24, w: FontWeight.w700)),
                  ),
                  const SizedBox(height: 6),
                  Text(foot, style: t(10.5, c: footColor)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedTile extends StatelessWidget {
  final Camera cam;
  const _FeedTile({required this.cam});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openCamera(context, cam.id),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          color: AppColors.navy,
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    LiveVideo(cam: cam),
                    Positioned(left: 8, top: 8, child: CamStamp(cam.channel)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cam.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t(11, w: FontWeight.w600, c: Colors.white)),
                    const SizedBox(height: 6),
                    Row(children: [
                      LiveDot(on: cam.online),
                      const SizedBox(width: 5),
                      Text(cam.statusLabel,
                          style: t(10,
                              w: FontWeight.w600,
                              c: cam.online
                                  ? const Color(0xFF3DDC84)
                                  : const Color(0xFF7A879C))),
                      const Spacer(),
                      Text(cam.channel,
                          style: t(9.5, c: const Color(0xFFB6C2D6))),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
