import 'package:flutter/material.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'alerts_screen.dart';

/// Every alert, newest first, with a status filter.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  AlertStatus? _filter;

  Color _statusColor(AlertStatus s) {
    switch (s) {
      case AlertStatus.active:
        return AppColors.red;
      case AlertStatus.acknowledged:
        return AppColors.yellow;
      case AlertStatus.resolved:
        return AppColors.green;
    }
  }

  String _statusLabel(AlertStatus s) {
    switch (s) {
      case AlertStatus.active:
        return 'Active';
      case AlertStatus.acknowledged:
        return 'Acknowledged';
      case AlertStatus.resolved:
        return 'Resolved';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Alert history',
      child: ListenableBuilder(
        listenable: app,
        builder: (context, child) {
          final list = app.alerts
              .where((a) => _filter == null || a.status == _filter)
              .toList()
            ..sort((a, b) => b.time.compareTo(a.time));
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in <AlertStatus?>[null, ...AlertStatus.values])
                    ChoiceChip(
                      label: Text(s == null ? 'All' : _statusLabel(s),
                          style: t(12, w: FontWeight.w600)),
                      selected: _filter == s,
                      selectedColor: AppColors.blueSoft,
                      onSelected: (_) => setState(() => _filter = s),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                      child: Text('No alerts', style: t(13, c: AppColors.muted))),
                ),
              for (final a in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () => openAlertTarget(context, a),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Pill('${a.priority.label} priority',
                                  bg: a.priority.bg, fg: a.priority.fg),
                              Row(children: [
                                Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                        color: _statusColor(a.status),
                                        shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Text(_statusLabel(a.status),
                                    style: t(11,
                                        w: FontWeight.w600, c: AppColors.muted)),
                              ]),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(a.title, style: t(14, w: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text('${a.location} · ${fmtTime12(a.time)}',
                              style: t(11.5, c: AppColors.muted)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
