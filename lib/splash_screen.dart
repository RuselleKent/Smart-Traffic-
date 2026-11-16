import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'widgets.dart';
import 'login_screen.dart';
import 'shell.dart';
import 'state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Design states: Starting up, 25, 50, 75, Ready 100.
  static const _steps = [0.08, 0.25, 0.5, 0.75, 1.0];
  int _i = 0;
  Timer? _timer;
  bool? _restored;
  bool _animDone = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    app
        .restoreSession()
        .timeout(const Duration(seconds: 8), onTimeout: () => false)
        .then((ok) {
      _restored = ok;
      _go();
    });
    _timer = Timer.periodic(const Duration(milliseconds: 650), (tm) {
      if (_i < _steps.length - 1) {
        setState(() => _i++);
      } else {
        tm.cancel();
        Future.delayed(const Duration(milliseconds: 700), () {
          _animDone = true;
          _go();
        });
      }
    });
  }

  bool _left = false;

  void _go() {
    if (!mounted || _left || !_animDone || _restored == null) return;
    _left = true;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          _restored! ? const MainShell() : const LoginScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    ));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _label {
    final v = _steps[_i];
    if (_i == 0) return 'Starting up...';
    if (v >= 1) return _restored == null ? 'Starting system…' : 'Ready · 100%';
    return 'Loading... ${(v * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    const soft = Color(0xFFB6C2D6);
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Logo + title: centered horizontally, slightly above the middle.
            Align(
              alignment: const Alignment(0, -0.12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TrafficLogo(),
                  const SizedBox(height: 40),
                  Text('Smart Traffic',
                      textAlign: TextAlign.center,
                      style: t(30, w: FontWeight.w600, c: Colors.white)),
                  const SizedBox(height: 14),
                  Text('Monitoring System',
                      textAlign: TextAlign.center, style: t(14, c: soft)),
                ],
              ),
            ),
            // Progress bar near the bottom, also centered.
            Align(
              alignment: const Alignment(0, 0.82),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 120,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: _steps[_i]),
                        duration: const Duration(milliseconds: 500),
                        builder: (context, v, child) =>
                            LinearProgressIndicator(
                          value: v,
                          minHeight: 3,
                          backgroundColor: const Color(0xFF3A465B),
                          valueColor:
                              const AlwaysStoppedAnimation(AppColors.blue),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(_label,
                      textAlign: TextAlign.center, style: t(11, c: soft)),
                ],
              ),
            ),
            // Small build stamp (lets you confirm the latest code is running).
            Align(
              alignment: const Alignment(0, 0.97),
              child: Text('v4.0',
                  style: t(10, c: soft.withValues(alpha: 0.45))),
            ),
          ],
        ),
      ),
    );
  }
}
