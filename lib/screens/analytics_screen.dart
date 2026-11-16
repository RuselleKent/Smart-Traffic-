import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'map_page.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const _ranges = ['today', '7d', '30d'];
  int _range = 0;
  DateTime _date = DateTime.now();
  AnalyticsData? _data;
  String? _error;
  bool _loading = false;
  Timer? _timer;

  bool get _isToday {
    final n = DateTime.now();
    return _date.year == n.year && _date.month == n.month && _date.day == n.day;
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (app.tab.value == 2 && app.authed.value) _load(silent: true);
    });
    app.tab.addListener(_onTab);
    app.authed.addListener(_onTab);
  }

  void _onTab() {
    if (app.tab.value == 2 && app.authed.value) _load(silent: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    app.tab.removeListener(_onTab);
    app.authed.removeListener(_onTab);
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_loading) return;
    _loading = true;
    if (!silent && mounted) setState(() => _error = null);
    final range = _range;
    final date = _date;
    try {
      final d = await app.fetchAnalytics(_ranges[range], date);
      if (!mounted || range != _range || date != _date) return;
      setState(() {
        _data = d;
        _error = null;
      });
    } catch (_) {
      if (mounted && _data == null) setState(() => _error = 'Could not load analytics.');
    } finally {
      _loading = false;
    }
  }

  void _setRange(int i) {
    setState(() {
      _range = i;
      _data = null;
    });
    _load();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      setState(() {
        _date = d;
        _data = null;
      });
      _load();
    }
  }

  Future<void> _export() async {
    final text = await app.exportReport(_ranges[_range], _date);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Traffic report', style: t(16, w: FontWeight.w700)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(text,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, height: 1.5)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: t(13, w: FontWeight.w600, c: AppColors.muted)),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (ctx.mounted) Navigator.pop(ctx);
              app.toast('Report copied to clipboard');
            },
            child: Text('Copy CSV', style: t(13, w: FontWeight.w600, c: AppColors.blue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, child) {
        if (_data == null && !_loading && _error == null && app.loaded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _data == null) _load();
          });
        }
        final s = _data;
        final pct = s?.pct ?? 0;
        final up = pct >= 0;
        String sign(int p) => p >= 0 ? '+' : '−';
        final speedPct = s?.speedPct ?? 0;
        final vehLabel = _range == 0
            ? (_isToday ? 'Vehicles today' : 'Vehicles')
            : (_range == 1 ? 'Vehicles · 7 days' : 'Vehicles · 30 days');

        return RefreshIndicator(
          onRefresh: () async {
            await app.refresh(force: true);
            await _load();
          },
          child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            const PageHeader(
                title: 'Analytics', subtitle: 'Traffic performance & trends'),
            SegmentedTabs(
              labels: const ['Today', '7 days', '30 days'],
              index: _range,
              onChanged: _setRange,
            ),
            const SizedBox(height: 18),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _pickDate,
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 20),
                const SizedBox(width: 10),
                Text(fmtDate(_date), style: t(14, w: FontWeight.w600)),
                const Icon(Icons.keyboard_arrow_down, size: 20),
                const Spacer(),
                Text((s == null || s.through == 'Full day') ? 'Full day' : 'Through ${s.through}',
                    style: t(11, c: AppColors.muted)),
              ]),
            ),
            const SizedBox(height: 18),
            if (s == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: _error != null
                      ? Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(_error!, textAlign: TextAlign.center, style: t(12.5, c: AppColors.muted)),
                          const SizedBox(height: 12),
                          OutlineBtn('Retry', icon: Icons.refresh, onTap: _load),
                        ])
                      : const CircularProgressIndicator(),
                ),
              )
            else ...[
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _Kpi(
                      color: AppColors.cyan,
                      label: vehLabel,
                      value: fmtInt(s.vehicles),
                      foot: '${sign(pct)} ${pct.abs()}% ${s.vsText}',
                      good: up,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Kpi(
                      color: AppColors.mint,
                      label: 'Avg. speed',
                      value: app.speedText(s.avgSpeedKmh),
                      foot:
                          '${sign(speedPct)} ${speedPct.abs()}% ${s.vsText}',
                      good: speedPct >= 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vehicle volume', style: t(18, w: FontWeight.w700)),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text('${s.bucket} traffic · vehicles',
                            style: t(11.5, c: AppColors.muted)),
                      ),
                      Pill('${sign(pct)} ${pct.abs()}% ${s.pillText}',
                          bg: up ? AppColors.blueSoft : const Color(0xFFFCDADA),
                          fg: up ? AppColors.blue : const Color(0xFFC62828)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: CustomPaint(painter: _BarsPainter(s)),
                  ),
                  const SizedBox(height: 16),
                  Wrap(spacing: 18, runSpacing: 6, children: [
                    _Key(AppColors.blue, s.curName),
                    _Key(const Color(0xFFC9DCFA), s.prevName),
                  ]),
                  const SizedBox(height: 12),
                  Text(
                    (_isToday && _range == 0)
                        ? 'Current hour is partial · Updated at ${fmtTime12(DateTime.now())}'
                        : 'Complete data · Updated at ${fmtTime12(DateTime.now())}',
                    style: t(11, c: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Congestion by zone', style: t(17, w: FontWeight.w700)),
                  const SizedBox(height: 18),
                  for (final z in s.zones) ...[
                    _ZoneBar(
                      zone: z,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => MapPage(focusZoneId: z.id))),
                    ),
                    if (z != s.zones.last) const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppColors.blueSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD3E3FB))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.trending_up, color: AppColors.blue, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.insightTitle, style: t(13, w: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(s.insightBody,
                            style: t(12, c: AppColors.muted, h: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _export,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border)),
                  alignment: Alignment.center,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.download_outlined,
                        size: 20, color: AppColors.blue),
                    const SizedBox(width: 10),
                    Text('Export traffic report',
                        style: t(13, w: FontWeight.w600, c: AppColors.blue)),
                  ]),
                ),
              ),
            ),
            ],
          ],
        ));
      },
    );
  }
}

class _Kpi extends StatelessWidget {
  final Color color;
  final String label, value, foot;
  final bool good;
  const _Kpi(
      {required this.color,
      required this.label,
      required this.value,
      required this.foot,
      required this.good});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: t(12, c: const Color(0xFF3F4B63))),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: t(28, w: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            Text(foot,
                style: t(10.5, c: good ? AppColors.greenDark : AppColors.red)),
          ],
        ),
      );
}

class _Key extends StatelessWidget {
  final Color c;
  final String label;
  const _Key(this.c, this.label);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: t(11, c: AppColors.muted)),
      ]);
}

class _ZoneBar extends StatelessWidget {
  final TrafficZone zone;
  final VoidCallback onTap;
  const _ZoneBar({required this.zone, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(zone.name, style: t(12, w: FontWeight.w600)),
                Text(zone.status, style: t(11, c: AppColors.muted)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(children: [
                Container(height: 6, color: AppColors.grayChip),
                FractionallySizedBox(
                  widthFactor: zone.load.clamp(0.02, 1.0).toDouble(),
                  child: Container(height: 6, color: zone.color.withValues(alpha: 0.7)),
                ),
              ]),
            ),
          ],
        ),
      );
}

class _BarsPainter extends CustomPainter {
  final AnalyticsData s;
  _BarsPainter(this.s);

  static const _steps = [100.0, 200.0, 250.0, 500.0, 1000.0, 2000.0, 2500.0,
      5000.0, 10000.0, 20000.0, 25000.0, 50000.0];

  String _fmt(double v) {
    if (v == 0) return '0';
    if (v >= 1000) {
      final k = v / 1000;
      return k == k.roundToDouble() ? '${k.round()}k' : '${k.toStringAsFixed(1)}k';
    }
    return v.round().toString();
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 36.0, bottom = 26.0;
    final h = size.height - bottom;
    final w = size.width - left;
    final grid = Paint()
      ..color = const Color(0xFFE8ECF3)
      ..strokeWidth = 1;

    double rawMax = 1;
    for (final v in [...s.current, ...s.previous]) {
      if (v > rawMax) rawMax = v;
    }
    var step = _steps.last;
    for (final st in _steps) {
      if (st * 4 >= rawMax) {
        step = st;
        break;
      }
    }
    final maxV = step * 4;

    void label(String txt, Offset o, {bool center = false}) {
      final tp = TextPainter(
        text: TextSpan(
            text: txt,
            style: const TextStyle(fontSize: 10, color: AppColors.muted)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          center ? o - Offset(tp.width / 2, 0) : o - Offset(0, tp.height / 2));
    }

    for (var i = 0; i <= 4; i++) {
      final y = h - h * i / 4;
      if (i > 0) canvas.drawLine(Offset(left, y), Offset(size.width, y), grid);
      label(_fmt(step * i), Offset(0, y));
    }
    canvas.drawLine(Offset(left, h), Offset(size.width, h), grid);

    final n = s.current.length;
    final slot = w / n;
    final bw = math.min(11.0, (slot - 6) / 2);
    final pCur = Paint()..color = AppColors.blue;
    final pPrev = Paint()..color = const Color(0xFFC9DCFA);

    for (var i = 0; i < n; i++) {
      final cx = left + slot * i + slot / 2;
      final ph = h * (s.previous[i] / maxV);
      final ch = h * (s.current[i] / maxV);
      canvas.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTWH(cx - bw - 1, h - ph, bw, ph),
              topLeft: const Radius.circular(2),
              topRight: const Radius.circular(2)),
          pPrev);
      canvas.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTWH(cx + 1, h - ch, bw, ch),
              topLeft: const Radius.circular(2),
              topRight: const Radius.circular(2)),
          pCur);
      if (s.labels[i].isNotEmpty) {
        label(s.labels[i], Offset(cx, h + 8), center: true);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) => true;
}
