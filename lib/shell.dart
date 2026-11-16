import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'feed.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';
import 'screens/dashboard_screen.dart';
import 'screens/cameras_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/settings_screen.dart';
import 'login_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    app.authed.addListener(_onAuth);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _pages = [
      const DashboardScreen(),
      const CamerasScreen(),
      const AnalyticsScreen(),
      const AlertsScreen(),
      SettingsScreen(onSignOut: _signOut),
    ];
  }

  @override
  void dispose() {
    app.authed.removeListener(_onAuth);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Pause the camera feeds while the app is in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      app.paused = false;
      app.refresh(force: true);
      FeedHub.instance.resumeAll();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      app.paused = true;
      FeedHub.instance.pauseAll();
    }
  }

  bool _leaving = false;

  void _signOut() => app.logout();

  void _onAuth() {
    if (app.authed.value || _leaving || !mounted) return;
    _leaving = true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _profile() {
    showAppSheet(
      context,
      (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                    color: Color(0xFFB9C7E4), shape: BoxShape.circle),
                child: const Icon(Icons.person_outline,
                    size: 28, color: AppColors.navy),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.userName, style: t(16, w: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(app.userEmail, style: t(12, c: AppColors.muted)),
                    const SizedBox(height: 6),
                    const Pill('Free account',
                        bg: AppColors.blueSoft, fg: AppColors.blue),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlineBtn('Settings', icon: Icons.settings_outlined,
                    onTap: () {
                  Navigator.pop(ctx);
                  app.tab.value = 4;
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryBtn('Sign out', icon: Icons.logout, onTap: () {
                  Navigator.pop(ctx);
                  _signOut();
                }),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Frame(
        child: ColoredBox(
          color: AppColors.bg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTopBar(onAvatarTap: _profile),
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: app.tab,
                  builder: (context, i, child) =>
                      IndexedStack(index: i, children: _pages),
                ),
              ),
              const _BottomNav(),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  static const _items = [
    (Icons.home_outlined, 'Dashboard'),
    (Icons.videocam_outlined, 'Cameras'),
    (Icons.bar_chart_rounded, 'Analytics'),
    (Icons.warning_amber_rounded, 'Alerts'),
    (Icons.settings_outlined, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    const soft = Color(0xFFB6C2D6);
    return Container(
      width: double.infinity,
      color: AppColors.navy,
      padding: EdgeInsets.fromLTRB(
          8, 10, 8, MediaQuery.of(context).padding.bottom + 10),
      child: ListenableBuilder(
        listenable: Listenable.merge([app, app.tab]),
        builder: (context, child) {
          final index = app.tab.value;
          return Row(
            children: List.generate(_items.length, (i) {
              final sel = i == index;
              final badge = i == 3 ? app.activeCount : 0;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => app.tab.value = i,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 44,
                            height: 30,
                            decoration: BoxDecoration(
                              color: sel ? AppColors.blue : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_items[i].$1,
                                size: 21, color: sel ? Colors.white : soft),
                          ),
                          if (badge > 0)
                            Positioned(
                              right: -2,
                              top: -4,
                              child: Container(
                                constraints: const BoxConstraints(
                                    minWidth: 16, minHeight: 16),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                    color: AppColors.red,
                                    borderRadius: BorderRadius.circular(8)),
                                alignment: Alignment.center,
                                child: Text('$badge',
                                    style: t(9,
                                        w: FontWeight.w700, c: Colors.white)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(_items[i].$2,
                            style: t(10,
                                w: sel ? FontWeight.w700 : FontWeight.w500,
                                c: sel ? Colors.white : soft)),
                      ),
                    ],
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
