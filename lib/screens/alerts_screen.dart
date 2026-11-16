import 'package:flutter/material.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'fullscreen_camera.dart';
import 'history_page.dart';
import 'map_page.dart';

void openAlertTarget(BuildContext context, TrafficAlert a) {
  if (a.cameraId != null) {
    if (app.cameraById(a.cameraId!) == null) {
      app.toast('That camera was removed');
      return;
    }
    openCamera(context, a.cameraId!);
  } else {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => MapPage(focusZoneId: a.zone)));
  }
}

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  int _tab = 0;
  AlertPriority? _priority;
  bool _newestFirst = true;

  void _priorityPicker() {
    showAppSheet(
      context,
      (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 18, 8, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Filter by priority', style: t(16, w: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final p in <AlertPriority?>[null, ...AlertPriority.values])
              ListTile(
                title: Text(p == null ? 'All priorities' : '${p.label} priority',
                    style: t(14)),
                trailing: _priority == p
                    ? const Icon(Icons.check, color: AppColors.blue)
                    : null,
                onTap: () {
                  setState(() => _priority = p);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, child) {
        final active = app.byStatus(AlertStatus.active);
        final status = [
          AlertStatus.active,
          AlertStatus.acknowledged,
          AlertStatus.resolved
        ][_tab];
        final shown = app
            .byStatus(status)
            .where((a) => _priority == null || a.priority == _priority)
            .toList()
          ..sort((a, b) =>
              _newestFirst ? b.time.compareTo(a.time) : a.time.compareTo(b.time));
        final recent = app.byStatus(AlertStatus.resolved)
          ..sort((a, b) => (b.resolvedAt ?? b.time).compareTo(a.resolvedAt ?? a.time));

        return RefreshIndicator(
          onRefresh: () => app.refresh(force: true),
          child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            const PageHeader(
                title: 'Alerts', subtitle: 'Incidents that need your attention'),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: active.isEmpty ? AppColors.mint : AppColors.rose,
                  borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: active.isEmpty ? AppColors.green : AppColors.red,
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(
                      active.isEmpty
                          ? Icons.check_rounded
                          : Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          active.isEmpty
                              ? 'No active alerts'
                              : '${active.length} active alert${active.length == 1 ? '' : 's'}',
                          style: t(20, w: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                          active.isEmpty
                              ? 'All clear'
                              : 'Requires attention · ${app.highActive} high priority',
                          style: t(11.5, c: const Color(0xFF3F4B63))),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 22),
            SegmentedTabs(
              labels: [
                'Active (${active.length})',
                'Acknowledged',
                'Resolved'
              ],
              index: _tab,
              blueText: true,
              onChanged: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _newestFirst = !_newestFirst),
                  child: Text(_newestFirst ? 'Newest first' : 'Oldest first',
                      style: t(12, c: AppColors.muted)),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _priorityPicker,
                  child: Row(children: [
                    const Icon(Icons.filter_list, size: 20, color: AppColors.blue),
                    const SizedBox(width: 6),
                    Text(
                        _priority == null
                            ? 'All priorities'
                            : '${_priority!.label} priority',
                        style: t(12, w: FontWeight.w600, c: AppColors.blue)),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Center(
                    child: Text('Nothing here', style: t(13, c: AppColors.muted))),
              ),
            for (final a in shown) _AlertCard(alert: a),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent activity', style: t(17, w: FontWeight.w700)),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HistoryPage())),
                  child: Text('View history +',
                      style: t(12, w: FontWeight.w600, c: AppColors.blue)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppCard(
              padding: EdgeInsets.zero,
              child: recent.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text('No resolved incidents yet',
                          style: t(12, c: AppColors.muted)),
                    )
                  : Column(children: [
                      for (var i = 0; i < recent.take(3).length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: AppColors.border),
                        _RecentRow(alert: recent[i]),
                      ],
                    ]),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => app.tab.value = 4,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.blueSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD3E3FB))),
                child: Row(children: [
                  const Icon(Icons.notifications_none,
                      color: AppColors.blue, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Stay ahead of incidents',
                            style: t(13, w: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                            app.push
                                ? 'Push notifications are on. Manage alert rules in Settings.'
                                : 'Push notifications are off. Turn them on in Settings.',
                            style: t(11.5, c: AppColors.muted, h: 1.4)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.blue),
                ]),
              ),
            ),
          ],
        ));
      },
    );
  }
}

class _RecentRow extends StatelessWidget {
  final TrafficAlert alert;
  const _RecentRow({required this.alert});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_outline,
                color: AppColors.green, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.title, style: t(13, w: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(alert.location, style: t(11.5, c: AppColors.muted)),
                  const SizedBox(height: 6),
                  Text(
                      '${alert.auto ? 'Resolved automatically' : 'Resolved'} · ${fmtTime12(alert.resolvedAt ?? alert.time)}',
                      style: t(11, w: FontWeight.w600, c: AppColors.greenDark)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _AlertCard extends StatelessWidget {
  final TrafficAlert alert;
  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final p = alert.priority;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Pill('${p.label} priority', bg: p.bg, fg: p.fg),
                Text(fmtTime12(alert.time), style: t(11, c: AppColors.muted)),
              ],
            ),
            const SizedBox(height: 14),
            Text(alert.title, style: t(17, w: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.location_on_outlined,
                  size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(alert.location, style: t(12, c: AppColors.muted))),
            ]),
            const SizedBox(height: 10),
            Text(alert.body, style: t(12.5, c: AppColors.muted, h: 1.5)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlineBtn(alert.actionLabel,
                    onTap: () => openAlertTarget(context, alert)),
              ),
              const SizedBox(width: 12),
              Expanded(child: _primary()),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _primary() {
    switch (alert.status) {
      case AlertStatus.active:
        return PrimaryBtn('Acknowledge', onTap: () => app.acknowledge(alert));
      case AlertStatus.acknowledged:
        return PrimaryBtn('Resolve', onTap: () => app.resolve(alert));
      case AlertStatus.resolved:
        return OutlineBtn('Reopen', onTap: () => app.reopen(alert));
    }
  }
}
