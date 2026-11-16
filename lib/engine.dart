import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'state.dart';

/// The built-in traffic system: predefined cameras and zones, a live traffic
/// simulation, alert rules and analytics. Everything runs on the phone.

// Vehicles per hour on an average weekday.
const List<int> kProfile = [
  780, 550, 500, 480, 1050, 2000, 3150, 4300, 4800, 4300, 3900, 4100,
  4400, 4100, 4000, 4500, 5200, 5600, 4700, 3600, 2700, 1900, 1300, 950
];

const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const _months3 = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

// ───────────── deterministic random (same numbers for the same date) ─────────────

/// 32-bit multiply that is exact on both the Dart VM and the web.
int _imul(int a, int b) {
  final ah = (a >> 16) & 0xFFFF, al = a & 0xFFFF;
  final bh = (b >> 16) & 0xFFFF, bl = b & 0xFFFF;
  return (al * bl + ((((ah * bl) + (al * bh)) & 0xFFFF) << 16)) & 0xFFFFFFFF;
}

double Function() _mulberry32(int seed) {
  var a = seed & 0xFFFFFFFF;
  return () {
    a = (a + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _imul(a ^ (a >> 15), 1 | a);
    t = ((t + _imul(t ^ (t >> 7), 61 | t)) & 0xFFFFFFFF) ^ t;
    return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0;
  };
}

int _seedFromKey(String k) {
  var h = 2166136261;
  for (final c in k.codeUnits) {
    h ^= c;
    h = _imul(h, 16777619);
  }
  return h & 0xFFFFFFFF;
}

String _dayKey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
double _clamp(double v, double lo, double hi) => math.min(hi, math.max(lo, v));
int _sum(Iterable<int> a) => a.fold(0, (x, y) => x + y);
int _pct(num cur, num prev) => prev == 0 ? 0 : ((cur / prev - 1) * 100).round();

double _dayFactor(DateTime d) =>
    d.weekday == DateTime.sunday ? 0.72 : (d.weekday == DateTime.saturday ? 0.82 : 1.0);

class _Day {
  final List<int> hours;
  final double speed;
  _Day(this.hours, this.speed);
}

_Day _seededDay(DateTime d) {
  final rng = _mulberry32(_seedFromKey(_dayKey(d)));
  final f = _dayFactor(d);
  final hours = <int>[];
  for (final p in kProfile) {
    hours.add((p * f * (0.92 + rng() * 0.16)).round());
  }
  final speed = 36 + rng() * 5 + (f < 1 ? 1.5 : 0);
  return _Day(hours, speed);
}

// ───────────────────────────── internal state ─────────────────────────────

class _CamSim {
  final String id, channel, location, direction;
  String name;
  bool online = true;
  DateTime lastChange;
  DateTime? restartUntil;
  _CamSim(this.id, this.name, this.channel, this.location, this.direction,
      this.lastChange);
}

class _ZoneSim {
  final String id, label, cameraId;
  final double lat, lng, mid, amp, period, phase;
  double load;
  _ZoneSim(this.id, this.label, this.cameraId, this.lat, this.lng, this.mid,
      this.amp, this.period, this.phase, this.load);
}

class _Incident {
  final String kind, title, body;
  final AlertPriority priority;
  const _Incident(this.kind, this.priority, this.title, this.body);
}

const _incidents = [
  _Incident('stopped', AlertPriority.medium, 'Vehicle stopped in lane',
      'A stationary vehicle was detected in the curbside lane. Review the live feed to confirm a possible obstruction.'),
  _Incident('crosswalk', AlertPriority.medium, 'Pedestrians blocking crosswalk',
      'A group of pedestrians has stayed on the crosswalk for over 60 seconds.'),
  _Incident('collision', AlertPriority.high, 'Possible collision detected',
      'Several vehicles stopped suddenly near the intersection. Review the live feed immediately.'),
];

// ───────────────────────────────── engine ─────────────────────────────────

class Engine {
  final math.Random _r = math.Random();
  final List<_CamSim> _cams;
  final List<_ZoneSim> _zones;
  final List<TrafficAlert> alerts;
  int alertCounter;

  /// Set whenever something that should be saved has changed.
  bool dirty = false;

  double speedKmh = 38;
  final Map<String, DateTime> _cooldowns = {};
  final Map<String, double> _overSecs = {};

  String _todayKey = '';
  List<int> _todayHours = List<int>.filled(24, 0);
  double _carry = 0;
  DateTime _last;

  Engine._(this._cams, this._zones, this.alerts, this.alertCounter, this._last);

  /// Predefined system. [since] = saved "connected since" times by camera id,
  /// [names] = saved camera labels, [saved] = saved alerts (null on first run).
  factory Engine.create(DateTime now,
      {Map<String, int>? since,
      Map<String, String>? names,
      List<TrafficAlert>? saved,
      int alertCounter = 100}) {
    DateTime up(String id, int minutes) => since != null && since[id] != null
        ? DateTime.fromMillisecondsSinceEpoch(since[id]!)
        : now.subtract(Duration(minutes: minutes));
    String nm(String id, String def) => names?[id] ?? def;
    final cams = [
      _CamSim('cam1', nm('cam1', 'Main Intersection'), 'CH 01',
          'Main St. & 1st Ave', 'Northbound', up('cam1', 7500)),
      _CamSim('cam2', nm('cam2', 'Southbound Lane'), 'CH 02',
          'Main St. near Market Sq.', 'Southbound', up('cam2', 3600)),
      _CamSim('cam3', nm('cam3', 'East Approach'), 'CH 03',
          'Main St. & Oak Rd.', 'Eastbound', up('cam3', 12900)),
      _CamSim('cam4', nm('cam4', 'West Approach'), 'CH 04',
          'Main St. & Pine Rd.', 'Westbound', up('cam4', 25)),
    ];
    final zones = [
      _ZoneSim('A', 'West approach', 'cam4', 14.6772, 121.0408, 0.30, 0.10, 23, 0.0, 0.30),
      _ZoneSim('B', 'Main intersection', 'cam1', 14.6760, 121.0437, 0.55, 0.12, 17, 1.7, 0.58),
      _ZoneSim('C', 'East approach', 'cam3', 14.6745, 121.0468, 0.78, 0.17, 21, 0.4, 0.90),
    ];
    DateTime ago(int m) => now.subtract(Duration(minutes: m));
    final list = saved ??
        [
          TrafficAlert(
              id: 'a1', key: 'congestion:C', priority: AlertPriority.high,
              title: 'Heavy congestion detected',
              location: 'Zone C · Main St., east approach',
              body: 'Traffic is moving slowly at the east approach. Queue length has exceeded the congestion threshold for 5 minutes.',
              zone: 'C', time: ago(4)),
          TrafficAlert(
              id: 'a2', key: 'incident:cam2:stopped', priority: AlertPriority.medium,
              title: 'Vehicle stopped in lane',
              location: 'CH 02 · Main St. near Market Sq.',
              body: 'A stationary vehicle was detected in the curbside lane. Review the live feed to confirm a possible obstruction.',
              zone: 'B', cameraId: 'cam2', time: ago(7)),
          TrafficAlert(
              id: 'a3', key: 'congestion:A', priority: AlertPriority.low,
              title: 'Traffic flow restored', location: 'Zone A · West approach',
              body: 'Traffic flow has returned to normal levels.', zone: 'A',
              time: ago(22), status: AlertStatus.resolved, resolvedAt: ago(22), auto: true),
          TrafficAlert(
              id: 'a4', key: 'offline:cam4', priority: AlertPriority.low,
              title: 'Camera connection restored',
              location: 'CH 04 · Main St. & Pine Rd.',
              body: 'The camera reconnected after a short interruption.',
              zone: 'A', cameraId: 'cam4', time: ago(44),
              status: AlertStatus.resolved, resolvedAt: ago(44), auto: true),
        ];
    final e = Engine._(cams, zones, list, alertCounter, now);
    e._ensureToday(now);
    e.dirty = saved == null;
    return e;
  }

  // ── time-based data ──
  void _ensureToday(DateTime now) {
    final key = _dayKey(now);
    if (_todayKey == key && _todayHours.length == 24) return;
    final seeded = _seededDay(now).hours;
    final h = now.hour;
    final frac = (now.minute * 60 + now.second) / 3600;
    _todayKey = key;
    _todayHours = [
      for (var i = 0; i < 24; i++)
        i < h ? seeded[i] : (i == h ? (seeded[i] * frac).round() : 0)
    ];
    _carry = 0;
  }

  List<int> _dayHours(DateTime date, DateTime now) {
    if (_dayKey(date) == _dayKey(now)) {
      _ensureToday(now);
      return _todayHours;
    }
    return _seededDay(date).hours;
  }

  double _daySpeed(DateTime date, DateTime now) =>
      _dayKey(date) == _dayKey(now) ? speedKmh : _seededDay(date).speed;

  int vehiclesToday(DateTime now) {
    _ensureToday(now);
    return _sum(_todayHours);
  }

  int vehiclesYesterdaySoFar(DateTime now) {
    final y = _seededDay(_addDays(now, -1)).hours;
    final frac = (now.minute * 60 + now.second) / 3600;
    var s = 0.0;
    for (var i = 0; i < now.hour; i++) {
      s += y[i];
    }
    s += y[now.hour] * frac;
    return s.round();
  }

  int get vehiclesDeltaPct => _lastDelta;
  int _lastDelta = 0;
  int speedDeltaPct(DateTime now) =>
      _pct(speedKmh, _seededDay(_addDays(now, -1)).speed);

  // ── views ──
  List<Camera> cameras(DateTime now) {
    for (final c in _cams) {
      _settle(c, now);
    }
    return [
      for (final c in _cams)
        Camera(
          id: c.id,
          name: c.name,
          channel: c.channel,
          location: c.location,
          direction: c.direction,
          online: c.online,
          restarting: c.restartUntil != null,
          upMinutes: c.online ? now.difference(c.lastChange).inMinutes : 0,
        )
    ];
  }

  Map<String, int> get sinceMs =>
      {for (final c in _cams) c.id: c.lastChange.millisecondsSinceEpoch};
  Map<String, String> get names => {for (final c in _cams) c.id: c.name};

  static double zoneSpeed(double load) => ((52 - load * 28) * 10).round() / 10;

  List<TrafficZone> zones() => [
        for (final z in _zones)
          TrafficZone(
            id: z.id,
            label: z.label,
            cameraId: _cams.any((c) => c.id == z.cameraId) ? z.cameraId : null,
            pos: LatLng(z.lat, z.lng),
            load: (z.load * 1000).round() / 1000,
            speedKmh: zoneSpeed(z.load),
          )
    ];

  // ── camera actions ──
  void rename(String id, String name) {
    _cams.firstWhere((c) => c.id == id).name = name;
    dirty = true;
  }

  /// Returns an error message, or null when the restart started.
  String? restart(String id, DateTime now, {int seconds = 9}) {
    final c = _cams.firstWhere((c) => c.id == id);
    _settle(c, now);
    if (c.restartUntil != null) return 'This camera is already restarting';
    if (!c.online) return 'This camera is offline';
    c.online = false;
    c.restartUntil = now.add(Duration(seconds: seconds));
    return null;
  }

  void _settle(_CamSim c, DateTime now) {
    final r = c.restartUntil;
    if (r != null && !now.isBefore(r)) {
      c.restartUntil = null;
      c.online = true;
      c.lastChange = now;
      dirty = true;
    }
  }

  // ── alerts ──
  static const _cooldown = Duration(minutes: 10);

  TrafficAlert? _open(String key) {
    for (final a in alerts) {
      if (a.key == key && a.status != AlertStatus.resolved) return a;
    }
    return null;
  }

  void _raise(DateTime now,
      {required String key,
      required AlertPriority priority,
      required String title,
      required String location,
      required String body,
      required String zone,
      String? cameraId}) {
    if (_open(key) != null) return;
    final cd = _cooldowns[key];
    if (cd != null && cd.isAfter(now)) return;
    alerts.insert(
        0,
        TrafficAlert(
          id: 'a${alertCounter++}',
          key: key,
          priority: priority,
          title: title,
          location: location,
          body: body,
          zone: zone,
          cameraId: cameraId,
          time: now,
        ));
    if (alerts.length > 200) alerts.removeRange(200, alerts.length);
    dirty = true;
  }

  void _autoResolve(String key, DateTime now) {
    final a = _open(key);
    if (a == null) return;
    a.status = AlertStatus.resolved;
    a.resolvedAt = now;
    a.auto = true;
    dirty = true;
  }

  void setStatus(TrafficAlert a, AlertStatus s, DateTime now) {
    a.status = s;
    if (s == AlertStatus.resolved) {
      a.resolvedAt = now;
      a.auto = false;
      _cooldowns[a.key] = now.add(_cooldown);
    }
    if (s == AlertStatus.active) {
      a.resolvedAt = null;
      _cooldowns.remove(a.key);
    }
    dirty = true;
  }

  String _camLocation(_CamSim c) => '${c.channel} · ${c.location}';

  void _rules(DateTime now, double dt) {
    // 1. congestion per zone
    for (final z in _zones) {
      _overSecs[z.id] = z.load > 0.85 ? (_overSecs[z.id] ?? 0) + dt : 0;
      final lower = z.label.toLowerCase();
      if ((_overSecs[z.id] ?? 0) >= 10) {
        _raise(now,
            key: 'congestion:${z.id}',
            priority: AlertPriority.high,
            title: 'Heavy congestion detected',
            location: 'Zone ${z.id} · Main St., $lower',
            zone: z.id,
            body:
                'Traffic is moving slowly at the $lower. Queue length has exceeded the congestion threshold.');
      }
      if (z.load < 0.7) _autoResolve('congestion:${z.id}', now);
    }
    // 2. camera health
    for (final c in _cams) {
      _settle(c, now);
      if (c.restartUntil != null) continue; // restarting on purpose: not a fault
      if (!c.online) {
        _raise(now,
            key: 'offline:${c.id}',
            priority: AlertPriority.medium,
            title: 'Camera connection lost',
            location: _camLocation(c),
            zone: 'B',
            cameraId: c.id,
            body: 'The camera stopped sending video. Check power and network connection.');
      } else {
        _autoResolve('offline:${c.id}', now);
      }
    }
    // 3. occasional incidents detected on a live feed (about one every 7 minutes)
    final active = alerts.where((a) => a.status == AlertStatus.active).length;
    if (active < 4 && _r.nextDouble() < dt / 450) {
      final online = _cams.where((c) => c.online).toList();
      if (online.isNotEmpty) {
        final c = online[_r.nextInt(online.length)];
        final inc = _incidents[_r.nextInt(_r.nextDouble() < 0.2 ? 3 : 2)];
        _raise(now,
            key: 'incident:${c.id}:${inc.kind}',
            priority: inc.priority,
            title: inc.title,
            location: _camLocation(c),
            body: inc.body,
            zone: 'B',
            cameraId: c.id);
      }
    }
  }

  // ── live tick ──
  void tick(DateTime now) {
    final dt = _clamp(now.difference(_last).inMilliseconds / 1000, 0.5, 60);
    _last = now;
    _ensureToday(now);

    // vehicles
    final h = now.hour;
    final perSec = kProfile[h] * _dayFactor(now) / 3600;
    _carry += perSec * dt * (0.85 + _r.nextDouble() * 0.3);
    final add = _carry.floor();
    _carry -= add;
    _todayHours[h] += add;

    // zones: slow waves plus noise
    final tMin = now.millisecondsSinceEpoch / 60000;
    final k = 1 - math.pow(0.75, dt / 5);
    for (final z in _zones) {
      final target = z.mid + z.amp * math.sin(2 * math.pi * tMin / z.period + z.phase);
      z.load = _clamp(
          z.load + (target - z.load) * k + (_r.nextDouble() - 0.5) * 0.03, 0.02, 0.99);
    }

    // speed follows congestion
    final avg = _zones.fold<double>(0, (a, z) => a + z.load) / _zones.length;
    final target = 49 - 16 * avg + (_r.nextDouble() - 0.5) * 2;
    final mix = 1 - math.pow(0.7, dt / 5);
    speedKmh = ((speedKmh * (1 - mix) + target * mix) * 10).round() / 10;

    _rules(now, dt);

    final y = vehiclesYesterdaySoFar(now);
    _lastDelta = _pct(_sum(_todayHours), y);
  }

  // ── analytics ──
  AnalyticsData analytics(String range, DateTime? dateIn, DateTime now) {
    final todayD = _dateOnly(now);
    var date = dateIn == null ? todayD : _dateOnly(dateIn);
    if (date.isAfter(todayD)) date = todayD;
    final isToday = _dayKey(date) == _dayKey(todayD);
    _ensureToday(now);

    final labels = <String>[];
    final cur = <double>[];
    final prev = <double>[];
    String curName, prevName, bucket, vsText, pillText;
    double speedCur, speedPrev;
    int total(DateTime d) => _sum(_dayHours(d, now));
    double avgOf(List<double> a) => a.fold<double>(0, (x, y) => x + y) / a.length;

    if (range == '7d') {
      for (var i = 6; i >= 0; i--) {
        final d = _addDays(date, -i);
        cur.add(total(d).toDouble());
        prev.add(total(_addDays(d, -7)).toDouble());
        labels.add(_weekdays[d.weekday % 7]);
      }
      curName = 'This week';
      prevName = 'Previous week';
      bucket = 'Daily';
      vsText = 'vs previous 7 days';
      pillText = 'this week';
      speedCur = avgOf([for (var i = 0; i < 7; i++) _daySpeed(_addDays(date, -i), now)]);
      speedPrev = avgOf([for (var i = 0; i < 7; i++) _daySpeed(_addDays(date, -i - 7), now)]);
    } else if (range == '30d') {
      for (var i = 5; i >= 0; i--) {
        var c = 0, p = 0;
        for (var k = 0; k < 5; k++) {
          final d = _addDays(date, -(i * 5 + k));
          c += total(d);
          p += total(_addDays(d, -30));
        }
        cur.add(c.toDouble());
        prev.add(p.toDouble());
        final ld = _addDays(date, -(i * 5 + 4));
        labels.add('${_months3[ld.month - 1]} ${ld.day}');
      }
      curName = 'Last 30 days';
      prevName = 'Previous 30 days';
      bucket = '5-day';
      vsText = 'vs previous 30 days';
      pillText = 'this month';
      speedCur = avgOf([for (var i = 0; i < 30; i++) _daySpeed(_addDays(date, -i), now)]);
      speedPrev = avgOf([for (var i = 0; i < 30; i++) _daySpeed(_addDays(date, -i - 30), now)]);
    } else {
      range = 'today';
      final h = _dayHours(date, now);
      final ph = _dayHours(_addDays(date, -1), now);
      if (isToday) {
        final n = now.hour;
        for (var i = 0; i <= n; i++) {
          cur.add(h[i].toDouble());
          final frac = i == n ? (now.minute * 60 + now.second) / 3600 : 1.0;
          prev.add((ph[i] * frac).roundToDouble());
          labels.add(i % 2 == 0 || i == n ? '${two(i)}:00' : '');
        }
        curName = 'Today';
        prevName = 'Yesterday';
        bucket = 'Hourly';
        vsText = 'vs yesterday';
        pillText = 'today';
      } else {
        for (var i = 0; i < 12; i++) {
          cur.add((h[i * 2] + h[i * 2 + 1]).toDouble());
          prev.add((ph[i * 2] + ph[i * 2 + 1]).toDouble());
          labels.add(i % 3 == 0 || i == 11 ? '${two(i * 2)}:00' : '');
        }
        curName = 'Selected day';
        prevName = 'Previous day';
        bucket = '2-hour';
        vsText = 'vs previous day';
        pillText = 'on this day';
      }
      speedCur = _daySpeed(date, now);
      speedPrev = _daySpeed(_addDays(date, -1), now);
    }

    final curSum = _sum(cur.map((e) => e.round()));
    final prevSum = _sum(prev.map((e) => e.round()));
    final vp = _pct(curSum, prevSum);
    final zv = zones();
    final busiest = zv.reduce((a, b) => a.load >= b.load ? a : b);
    return AnalyticsData(
      range: range,
      date: date,
      isToday: isToday,
      bucket: bucket,
      labels: labels,
      current: cur,
      previous: prev,
      curName: curName,
      prevName: prevName,
      vsText: vsText,
      pillText: pillText,
      vehicles: curSum,
      previousVehicles: prevSum,
      pct: vp,
      avgSpeedKmh: (speedCur * 10).round() / 10,
      speedPct: _pct(speedCur, speedPrev),
      through: isToday && range == 'today' ? '${two(now.hour)}:${two(now.minute)}' : 'Full day',
      zones: zv,
      insightTitle: now.hour < 12 ? 'Morning traffic is building' : 'Traffic update',
      insightBody:
          'Volume is ${vp.abs()}% ${vp >= 0 ? 'above' : 'below'} ${range == 'today' ? 'yesterday' : 'the previous period'}. The ${busiest.label.toLowerCase()} has the highest congestion; monitor zone ${busiest.id}.',
    );
  }

  String csv(String range, DateTime? date, DateTime now) {
    final r = analytics(range, date, now);
    final l = <String>[
      'Smart Traffic report',
      'Date,${_dayKey(r.date)}',
      'Range,${r.range}',
      'Vehicles,${r.vehicles}',
      'Previous period vehicles,${r.previousVehicles}',
      'Change %,${r.pct}',
      'Avg speed km/h,${r.avgSpeedKmh}',
      '',
      'period,${r.curName},${r.prevName}',
    ];
    for (var i = 0; i < r.current.length; i++) {
      final label = r.labels[i].isEmpty ? '#${i + 1}' : r.labels[i];
      l.add('$label,${r.current[i].round()},${r.previous[i].round()}');
    }
    l.add('');
    l.add('zone,status,load %,avg speed km/h');
    for (final z in r.zones) {
      l.add('${z.name},${z.status},${(z.load * 100).round()},${z.speedKmh}');
    }
    return '${l.join('\n')}\n';
  }
}
