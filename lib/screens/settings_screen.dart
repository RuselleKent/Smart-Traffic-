import 'package:flutter/material.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'snapshots_page.dart';

class SettingsScreen extends StatelessWidget {
  final VoidCallback onSignOut;
  const SettingsScreen({super.key, required this.onSignOut});

  static const _refreshOptions = {
    '1 second': 1,
    '5 seconds': 5,
    '10 seconds': 10,
    '30 seconds': 30,
  };

  String get _refreshLabel => _refreshOptions.entries
      .firstWhere((e) => e.value == app.refreshSeconds,
          orElse: () => const MapEntry('5 seconds', 5))
      .key;

  Future<void> _pick(BuildContext context, String title, List<String> opts,
      String cur, ValueChanged<String> set,
      {List<String> disabled = const []}) async {
    final v = await showAppSheet<String>(
      context,
      (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 18),
            Text(title, style: t(16, w: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final o in opts)
              ListTile(
                enabled: !disabled.contains(o),
                title: Text(o, style: t(14)),
                trailing: o == cur
                    ? const Icon(Icons.check, color: AppColors.blue)
                    : null,
                onTap: () => Navigator.pop(ctx, o),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (v != null) set(v);
  }

  Future<void> _changePassword(BuildContext context) async {
    final cur = TextEditingController();
    final nw = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Change password', style: t(16, w: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: cur,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password')),
          const SizedBox(height: 12),
          TextField(
              controller: nw,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'New password', helperText: 'At least 6 characters')),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: t(13, w: FontWeight.w600, c: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Change', style: t(13, w: FontWeight.w600, c: AppColors.blue)),
          ),
        ],
      ),
    );
    if (ok == true) await app.changePassword(cur.text, nw.text);
    cur.dispose();
    nw.dispose();
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showInfo(
        context, 'Sign out?', 'You will need to sign in again to continue.',
        confirm: 'Sign out');
    if (ok == true) onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, child) {
        final offline = app.cameras.length - app.onlineCount;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            const PageHeader(
                title: 'Settings', subtitle: 'Preferences & system controls'),
            AppCard(
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                      color: Color(0xFFB9C7E4), shape: BoxShape.circle),
                  child: const Icon(Icons.person_outline,
                      color: AppColors.navy, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.userName, style: t(15, w: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(app.userEmail, style: t(11.5, c: AppColors.muted)),
                    ],
                  ),
                ),
                const Pill('Free', bg: AppColors.blueSoft, fg: AppColors.blue),
              ]),
            ),
            const SizedBox(height: 22),
            Text('Notifications', style: t(17, w: FontWeight.w700)),
            const SizedBox(height: 12),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                _Row(
                  icon: Icons.notifications_none,
                  label: 'Push notifications',
                  trailing: Switch(
                      value: app.push,
                      activeThumbColor: AppColors.blue,
                      onChanged: app.setPush),
                ),
                const _Div(),
                _Row(
                  icon: Icons.warning_amber_rounded,
                  label: 'Critical alerts only',
                  trailing: Switch(
                      value: app.criticalOnly,
                      activeThumbColor: AppColors.blue,
                      onChanged: app.push ? app.setCriticalOnly : null),
                ),
              ]),
            ),
            const SizedBox(height: 22),
            Text('Monitoring', style: t(17, w: FontWeight.w700)),
            const SizedBox(height: 12),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                _Row(
                  icon: Icons.sync,
                  label: 'Feed refresh interval',
                  value: _refreshLabel,
                  onTap: () => _pick(
                      context,
                      'Feed refresh interval',
                      _refreshOptions.keys.toList(),
                      _refreshLabel,
                      (v) => app.setRefresh(_refreshOptions[v] ?? 5)),
                ),
                const _Div(),
                _Row(
                  icon: Icons.speed,
                  label: 'Speed units',
                  value: app.speedUnit,
                  onTap: () => _pick(context, 'Speed units', ['km/h', 'mph'],
                      app.speedUnit, app.setSpeedUnit),
                ),
                const _Div(),
                _Row(
                  icon: Icons.videocam_outlined,
                  label: 'Video quality',
                  value: app.quality,
                  onTap: () => _pick(context, 'Video quality',
                      ['480p', '720p', '1080p'], app.quality, app.setQuality),
                ),
              ]),
            ),
            const SizedBox(height: 22),
            Text('System', style: t(17, w: FontWeight.w700)),
            const SizedBox(height: 12),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                _Row(
                  icon: Icons.wb_sunny_outlined,
                  label: 'Appearance',
                  value: 'Light',
                  onTap: () => _pick(
                    context,
                    'Appearance',
                    ['Light', 'Dark (coming soon)'],
                    'Light',
                    (_) {},
                    disabled: ['Dark (coming soon)'],
                  ),
                ),
                const _Div(),
                _Row(
                  icon: Icons.photo_library_outlined,
                  label: 'Saved snapshots',
                  value: '${app.snapshots.length}',
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SnapshotsPage())),
                ),
                const _Div(),
                _Row(
                  icon: Icons.lock_outline,
                  label: 'Change password',
                  onTap: () => _changePassword(context),
                ),
                const _Div(),
                _Row(
                  icon: Icons.help_outline,
                  label: 'Help & support',
                  onTap: () => showInfo(
                      context,
                      'Help & support',
                      'Cameras: open the Cameras tab to watch a live feed, take a snapshot, rename a camera or restart one that is not responding.\n\nAlerts: acknowledge an alert when you are handling it, resolve it when it is fixed.\n\nEverything runs on this device, so no internet connection is needed except to load the map.\n\nSmart Traffic Monitoring System · Version 4.0.0'),
                ),
                const _Div(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Text('System status', style: t(11.5, c: AppColors.muted)),
                    const Spacer(),
                    Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                            color: offline == 0
                                    ? AppColors.green
                                    : AppColors.yellow,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(
                        offline == 0
                                ? 'All services online'
                                : '$offline camera${offline == 1 ? '' : 's'} offline',
                        style: t(11.5,
                            w: FontWeight.w600,
                            c: offline == 0
                                ? AppColors.greenDark
                                : const Color(0xFF7A6200))),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _confirmSignOut(context),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border)),
                  alignment: Alignment.center,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.logout, size: 19, color: AppColors.red),
                    const SizedBox(width: 10),
                    Text('Sign out',
                        style: t(13, w: FontWeight.w600, c: AppColors.red)),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Center(
              child: Text(
                'Smart Traffic Monitoring System\nVersion 4.0.0 · Updated at ${app.lastSync == null ? '—' : fmtTime12(app.lastSync!)}',
                textAlign: TextAlign.center,
                style: t(11, c: AppColors.muted, h: 1.6),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Div extends StatelessWidget {
  const _Div();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: AppColors.border);
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _Row(
      {required this.icon,
      required this.label,
      this.value,
      this.trailing,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(children: [
          Icon(icon, size: 21, color: AppColors.ink),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: t(13, w: FontWeight.w600))),
          if (value != null) Text(value!, style: t(11.5, c: AppColors.muted)),
          if (trailing != null)
            trailing!
          else
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
            ),
        ]),
      ),
    );
  }
}
