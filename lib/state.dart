import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import 'engine.dart';
import 'feed.dart';
import 'theme.dart';

// ───────────────────────── formatting helpers ─────────────────────────

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December'
];

String two(int n) => n.toString().padLeft(2, '0');
String fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';
String fmtShortDate(DateTime d) =>
    '${_months[d.month - 1].substring(0, 3)} ${d.day}';
String fmtTime12(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${two(h)}:${two(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
}

String fmtClock(DateTime d) => '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
String fmtHm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
String fmtInt(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

// ───────────────────────────── models ─────────────────────────────

enum AlertStatus { active, acknowledged, resolved }

enum AlertPriority { high, medium, low }

extension PriorityStyle on AlertPriority {
  String get label {
    switch (this) {
      case AlertPriority.high:
        return 'High';
      case AlertPriority.medium:
        return 'Medium';
      case AlertPriority.low:
        return 'Low';
    }
  }

  Color get bg {
    switch (this) {
      case AlertPriority.high:
        return const Color(0xFFFCDADA);
      case AlertPriority.medium:
        return const Color(0xFFEDE4BE);
      case AlertPriority.low:
        return AppColors.mint;
    }
  }

  Color get fg {
    switch (this) {
      case AlertPriority.high:
        return const Color(0xFFC62828);
      case AlertPriority.medium:
        return const Color(0xFF7A6200);
      case AlertPriority.low:
        return AppColors.greenDark;
    }
  }
}

const kDirections = ['Northbound', 'Southbound', 'Eastbound', 'Westbound'];



DateTime _dt(dynamic v) => DateTime.parse(v as String).toLocal();

/// Error shown to the user (wrong password, bad input...).
class AppError implements Exception {
  final String message;
  AppError(this.message);
  @override
  String toString() => message;
}

class Camera {
  final String id;
  final String name;
  final String channel;
  final String location;
  final String direction;
  final bool online;
  final bool restarting;
  final int upMinutes;
  Camera({
    required this.id,
    required this.name,
    required this.channel,
    required this.location,
    required this.direction,
    required this.online,
    this.restarting = false,
    this.upMinutes = 0,
  });

  /// Bundled video for this camera.
  String get feedAsset => 'assets/videos/$id.mp4';
  String get thumbAsset => 'assets/images/$id.jpg';

  String get statusLabel =>
      restarting ? 'Restarting' : (online ? 'Live' : 'Offline');

  String get uptime {
    final m = upMinutes;
    if (m < 1) return 'Just now';
    if (m < 60) return '${m}m';
    if (m < 1440) return '${m ~/ 60}h ${m % 60}m';
    return '${m ~/ 1440}d ${(m % 1440) ~/ 60}h';
  }
}

class Snapshot {
  final String id;
  final String cameraId;
  final String cameraName;
  final DateTime time;
  final String asset;
  Snapshot(this.id, this.cameraId, this.cameraName, this.time, this.asset);

  Map<String, dynamic> toJson() => {
        'id': id,
        'cameraId': cameraId,
        'cameraName': cameraName,
        'time': time.toUtc().toIso8601String(),
        'asset': asset,
      };

  factory Snapshot.fromJson(Map<String, dynamic> j) => Snapshot(
        j['id'] as String,
        j['cameraId'] as String,
        j['cameraName'] as String,
        _dt(j['time']),
        j['asset'] as String,
      );
}

class TrafficAlert {
  final String id;
  final String key;
  final AlertPriority priority;
  final String title;
  final String location;
  final String body;
  final String zone;
  final String? cameraId;
  final DateTime time;
  AlertStatus status;
  DateTime? resolvedAt;
  bool auto;
  TrafficAlert({
    required this.id,
    required this.key,
    required this.priority,
    required this.title,
    required this.location,
    required this.body,
    required this.zone,
    this.cameraId,
    required this.time,
    this.status = AlertStatus.active,
    this.resolvedAt,
    this.auto = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'priority': priority.name,
        'title': title,
        'location': location,
        'body': body,
        'zone': zone,
        'cameraId': cameraId,
        'time': time.toUtc().toIso8601String(),
        'status': status.name,
        'resolvedAt': resolvedAt?.toUtc().toIso8601String(),
        'auto': auto,
      };

  factory TrafficAlert.fromJson(Map<String, dynamic> j) => TrafficAlert(
        id: j['id'] as String,
        key: (j['key'] as String?) ?? j['id'] as String,
        priority: AlertPriority.values.firstWhere((p) => p.name == j['priority'],
            orElse: () => AlertPriority.medium),
        title: j['title'] as String,
        location: j['location'] as String,
        body: j['body'] as String,
        zone: (j['zone'] as String?) ?? 'B',
        cameraId: j['cameraId'] as String?,
        time: _dt(j['time']),
        status: AlertStatus.values.firstWhere((s) => s.name == j['status'],
            orElse: () => AlertStatus.active),
        resolvedAt: j['resolvedAt'] == null ? null : _dt(j['resolvedAt']),
        auto: j['auto'] == true,
      );

  String get actionLabel => cameraId != null ? 'View camera' : 'View on map';
}

class TrafficZone {
  final String id;
  final String label;
  final String? cameraId;
  final LatLng pos;
  final double load;
  final double speedKmh;
  TrafficZone({
    required this.id,
    required this.label,
    required this.cameraId,
    required this.pos,
    required this.load,
    required this.speedKmh,
  });

  String get name => '$id · $label';
  String get status =>
      load < 0.4 ? 'Normal' : (load < 0.75 ? 'Moderate' : 'Heavy');
  Color get color => load < 0.4
      ? AppColors.green
      : (load < 0.75 ? AppColors.yellow : AppColors.red);
  Color get track => load < 0.4
      ? const Color(0xFFC8F7D4)
      : (load < 0.75 ? const Color(0xFFF6EBB8) : const Color(0xFFF7B8B8));
}

class AnalyticsData {
  final String range;
  final DateTime date;
  final bool isToday;
  final String bucket;
  final List<String> labels;
  final List<double> current;
  final List<double> previous;
  final String curName;
  final String prevName;
  final String vsText;
  final String pillText;
  final int vehicles;
  final int previousVehicles;
  final int pct;
  final double avgSpeedKmh;
  final int speedPct;
  final String through;
  final List<TrafficZone> zones;
  final String insightTitle;
  final String insightBody;
  AnalyticsData({
    required this.range,
    required this.date,
    required this.isToday,
    required this.bucket,
    required this.labels,
    required this.current,
    required this.previous,
    required this.curName,
    required this.prevName,
    required this.vsText,
    required this.pillText,
    required this.vehicles,
    required this.previousVehicles,
    required this.pct,
    required this.avgSpeedKmh,
    required this.speedPct,
    required this.through,
    required this.zones,
    required this.insightTitle,
    required this.insightBody,
  });
}

// ──────────────────────────── app state ────────────────────────────

const kTestEmail = 'free@gmail.com';
const kTestPassword = 'freeaccount';

class AppState extends ChangeNotifier {
  SharedPreferences? _prefs;
  Engine? _engine;

  /// Real wall clock, ticking every second.
  final ValueNotifier<DateTime> clock = ValueNotifier<DateTime>(DateTime.now());

  /// Selected bottom-navigation tab.
  final ValueNotifier<int> tab = ValueNotifier<int>(0);

  /// false -> the app should show the sign-in screen.
  final ValueNotifier<bool> authed = ValueNotifier<bool>(false);

  final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  String userEmail = '';
  String userName = 'Traffic operator';
  String savedEmail = '';
  bool rememberMe = false;
  String _password = kTestPassword;

  // settings
  bool push = true;
  bool criticalOnly = true;
  int refreshSeconds = 5;
  String speedUnit = 'km/h';
  String quality = '1080p';

  // live metrics
  int vehiclesToday = 0;
  int vehiclesDeltaPct = 0;
  double speedKmh = 0;
  int speedDeltaPct = 0;

  List<TrafficZone> zones = [];
  List<Camera> cameras = [];
  List<TrafficAlert> alerts = [];
  List<Snapshot> snapshots = [];
  String? selectedId;

  // The system is built in, so it is always available.
  bool connected = true;
  DateTime? lastSync;
  bool loaded = false;
  bool paused = false;
  final Set<String> _seenAlerts = {};
  bool _alertsPrimed = false;
  int _snapCounter = 0;

  Timer? _clockTimer;
  Timer? _dataTimer;
  Timer? _fastTimer;

  // ── lifecycle ──
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    savedEmail = p.getString('email') ?? '';
    rememberMe = p.getBool('remember') ?? false;
    _password = p.getString('password') ?? kTestPassword;
    push = p.getBool('push') ?? true;
    criticalOnly = p.getBool('criticalOnly') ?? true;
    refreshSeconds = p.getInt('refreshSeconds') ?? 5;
    speedUnit = p.getString('speedUnit') ?? 'km/h';
    quality = p.getString('quality') ?? '1080p';
    _snapCounter = p.getInt('snap_counter') ?? 0;
    _loadEngine();
    _loadSnapshotsFromPrefs();
  }

  void _loadEngine() {
    final p = _prefs!;
    final now = DateTime.now();
    Map<String, int>? since;
    Map<String, String>? names;
    List<TrafficAlert>? saved;
    try {
      final s = p.getString('cam_since');
      if (s != null) {
        since = (jsonDecode(s) as Map).map((k, v) => MapEntry(k as String, (v as num).toInt()));
      }
      final n = p.getString('cam_names');
      if (n != null) {
        names = (jsonDecode(n) as Map).map((k, v) => MapEntry(k as String, v as String));
      }
      final a = p.getString('alerts');
      if (a != null) {
        saved = (jsonDecode(a) as List)
            .map((e) => TrafficAlert.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {
      since = null;
      names = null;
      saved = null;
    }
    _engine = Engine.create(now,
        since: since,
        names: names,
        saved: saved,
        alertCounter: p.getInt('alert_counter') ?? 100);
    _pull(now);
  }

  void start() {
    _clockTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      clock.value = DateTime.now();
    });
  }

  void _restartData() {
    _dataTimer?.cancel();
    _dataTimer = Timer.periodic(Duration(seconds: refreshSeconds), (_) {
      if (!paused) refresh();
    });
  }

  void _stopData() {
    _dataTimer?.cancel();
    _dataTimer = null;
  }

  Future<bool> restoreSession() async {
    if (_prefs?.getBool('signed_in') != true) return false;
    userEmail = _prefs?.getString('user') ?? kTestEmail;
    _startSession();
    return true;
  }

  void _startSession() {
    _alertsPrimed = false;
    _seenAlerts.clear();
    refresh(force: true);
    authed.value = true;
    _restartData();
  }

  Future<void> login(String email, String password, bool remember) async {
    final e = email.trim().toLowerCase();
    if (e != kTestEmail || password != _password) {
      throw AppError('Incorrect email or password.');
    }
    userEmail = e;
    rememberMe = remember;
    savedEmail = remember ? e : '';
    await _prefs?.setString('email', savedEmail);
    await _prefs?.setBool('remember', remember);
    await _prefs?.setBool('signed_in', true);
    await _prefs?.setString('user', e);
    _startSession();
  }

  Future<void> logout() async {
    _stopData();
    await _persist(force: true);
    await _prefs?.setBool('signed_in', false);
    loaded = false;
    cameras = [];
    alerts = [];
    zones = [];
    _seenAlerts.clear();
    _alertsPrimed = false;
    selectedId = null;
    tab.value = 0;
    authed.value = false;
    FeedHub.instance.disposeAll();
    _loadEngine();
    notifyListeners();
  }

  // ── data ──
  void _pull(DateTime now) {
    final e = _engine!;
    vehiclesToday = e.vehiclesToday(now);
    vehiclesDeltaPct = e.vehiclesDeltaPct;
    speedKmh = e.speedKmh;
    speedDeltaPct = e.speedDeltaPct(now);
    cameras = e.cameras(now);
    zones = e.zones();
    alerts = List<TrafficAlert>.from(e.alerts);
  }

  Future<void> refresh({bool force = false}) async {
    final e = _engine;
    if (e == null) return;
    final now = DateTime.now();
    e.tick(now);
    _pull(now);
    _notifyNewAlerts(alerts);
    lastSync = now;
    loaded = true;
    if (cameras.any((c) => c.restarting)) {
      _fastTimer ??= Timer(const Duration(milliseconds: 1500), () {
        _fastTimer = null;
        refresh(force: true);
      });
    }
    if (selectedId != null && cameraById(selectedId!) == null) selectedId = null;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist({bool force = false}) async {
    final e = _engine;
    final p = _prefs;
    if (e == null || p == null) return;
    if (!e.dirty && !force) return;
    e.dirty = false;
    await p.setString('alerts', jsonEncode(e.alerts.map((a) => a.toJson()).toList()));
    await p.setInt('alert_counter', e.alertCounter);
    await p.setString('cam_since', jsonEncode(e.sinceMs));
    await p.setString('cam_names', jsonEncode(e.names));
  }

  void _notifyNewAlerts(List<TrafficAlert> fresh) {
    final show = <TrafficAlert>[];
    for (final a in fresh) {
      if (_seenAlerts.add(a.id) &&
          _alertsPrimed &&
          a.status == AlertStatus.active) {
        show.add(a);
      }
    }
    _alertsPrimed = true;
    if (show.isEmpty || !push) return;
    final list = criticalOnly
        ? show.where((a) => a.priority == AlertPriority.high).toList()
        : show;
    if (list.isEmpty) return;
    final a = list.first;
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(list.length == 1
            ? 'New alert: ${a.title}'
            : '${list.length} new alerts · ${a.title}'),
        action: SnackBarAction(label: 'View', onPressed: () => tab.value = 3),
      ));
  }

  void toast(String message) {
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Text(message),
      ));
  }

  // ── derived values ──
  int get onlineCount => cameras.where((c) => c.online).length;
  int get restartingCount => cameras.where((c) => c.restarting).length;
  int get activeCount =>
      alerts.where((a) => a.status == AlertStatus.active).length;
  int get highActive => alerts
      .where((a) => a.status == AlertStatus.active && a.priority == AlertPriority.high)
      .length;
  List<TrafficAlert> byStatus(AlertStatus s) =>
      alerts.where((a) => a.status == s).toList();

  TrafficZone get busiest => zones.reduce((a, b) => a.load >= b.load ? a : b);
  TrafficZone? zoneById(String id) {
    for (final z in zones) {
      if (z.id == id) return z;
    }
    return null;
  }

  String get congestionLabel {
    if (zones.isEmpty) return '—';
    final z = zones.length > 1 ? zones[1] : zones.first;
    return z.status == 'Normal' ? 'Light' : z.status;
  }

  String speedText(double kmh) => speedUnit == 'mph'
      ? '${(kmh * 0.621371).round()} mph'
      : '${kmh.round()} km/h';

  String get resolutionText => quality == '1080p'
      ? '1920 × 1080'
      : (quality == '720p' ? '1280 × 720' : '854 × 480');

  Camera? cameraById(String id) {
    for (final c in cameras) {
      if (c.id == id) return c;
    }
    return null;
  }

  Camera? get selected {
    if (cameras.isEmpty) return null;
    return cameraById(selectedId ?? '') ?? cameras.first;
  }

  // ── settings ──
  void _saved() {
    notifyListeners();
  }

  Future<void> setRefresh(int seconds) async {
    refreshSeconds = seconds;
    if (_dataTimer != null) _restartData();
    await _prefs?.setInt('refreshSeconds', seconds);
    _saved();
  }

  Future<void> setSpeedUnit(String u) async {
    speedUnit = u;
    await _prefs?.setString('speedUnit', u);
    _saved();
  }

  Future<void> setQuality(String q) async {
    quality = q;
    await _prefs?.setString('quality', q);
    _saved();
  }

  Future<void> setPush(bool v) async {
    push = v;
    await _prefs?.setBool('push', v);
    _saved();
  }

  Future<void> setCriticalOnly(bool v) async {
    criticalOnly = v;
    await _prefs?.setBool('criticalOnly', v);
    _saved();
  }

  Future<bool> changePassword(String current, String next) async {
    if (current != _password) {
      toast('Current password is incorrect');
      return false;
    }
    if (next.length < 8) {
      toast('Use at least 8 characters');
      return false;
    }
    _password = next;
    await _prefs?.setString('password', next);
    toast('Password changed');
    return true;
  }

  // ── cameras ──
  void select(Camera c) {
    selectedId = c.id;
    notifyListeners();
  }

  Future<bool> renameCamera(Camera c, String name) async {
    if (name.trim().isEmpty) {
      toast('Enter a name');
      return false;
    }
    _engine!.rename(c.id, name.trim());
    toast('Camera renamed');
    await refresh(force: true);
    return true;
  }

  /// Power-cycles the camera: it drops for a few seconds, then reconnects.
  Future<bool> restartCamera(Camera c) async {
    final err = _engine!.restart(c.id, DateTime.now());
    if (err != null) {
      toast(err);
      return false;
    }
    toast('Restarting ${c.channel}…');
    await refresh(force: true);
    return true;
  }

  // ── snapshots ──
  void _loadSnapshotsFromPrefs() {
    try {
      final s = _prefs?.getString('snapshots');
      if (s == null) return;
      snapshots = (jsonDecode(s) as List)
          .map((e) => Snapshot.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      snapshots = [];
    }
  }

  Future<void> _saveSnapshots() async {
    await _prefs?.setString(
        'snapshots', jsonEncode(snapshots.map((s) => s.toJson()).toList()));
    await _prefs?.setInt('snap_counter', _snapCounter);
  }

  /// Captures the frame that is on screen right now (matched to playback).
  Future<Snapshot?> takeSnapshot(Camera c) async {
    if (!c.online) {
      toast(c.restarting
          ? '${c.channel} is restarting. Try again in a moment.'
          : '${c.channel} is offline');
      return null;
    }
    final pos = FeedHub.instance.positionOf(c.feedAsset);
    final idx = (pos.inMilliseconds / 500).floor() % 24;
    _snapCounter++;
    final s = Snapshot(
      's$_snapCounter',
      c.id,
      c.name,
      DateTime.now(),
      'assets/frames/${c.id}_${two(idx + 1)}.jpg',
    );
    snapshots.insert(0, s);
    if (snapshots.length > 100) snapshots.removeRange(100, snapshots.length);
    notifyListeners();
    await _saveSnapshots();
    return s;
  }

  Future<void> loadSnapshots() async {}

  Future<void> deleteSnapshot(Snapshot s) async {
    snapshots.remove(s);
    notifyListeners();
    await _saveSnapshots();
    toast('Snapshot deleted');
  }

  // ── alerts ──
  Future<void> _alertAction(TrafficAlert a, AlertStatus to, String message) async {
    _engine!.setStatus(a, to, DateTime.now());
    toast(message);
    await refresh(force: true);
  }

  Future<void> acknowledge(TrafficAlert a) =>
      _alertAction(a, AlertStatus.acknowledged, 'Alert acknowledged');
  Future<void> resolve(TrafficAlert a) =>
      _alertAction(a, AlertStatus.resolved, 'Alert resolved');
  Future<void> reopen(TrafficAlert a) =>
      _alertAction(a, AlertStatus.active, 'Alert reopened');

  // ── analytics ──
  Future<AnalyticsData> fetchAnalytics(String range, DateTime? date) async =>
      _engine!.analytics(range, date, DateTime.now());

  Future<String> exportReport(String range, DateTime? date) async =>
      _engine!.csv(range, date, DateTime.now());
}

final AppState app = AppState();
