import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'fullscreen_camera.dart';

const LatLng kMapCenter = LatLng(14.6760, 121.0437);

/// Street map (OpenStreetMap tiles, no API key) with live zone markers.
class ZoneMap extends StatelessWidget {
  final bool interactive;
  final MapController? controller;
  final LatLng center;
  final double zoom;
  final ValueChanged<TrafficZone>? onZoneTap;
  final VoidCallback? onMapTap;

  const ZoneMap({
    super.key,
    this.interactive = true,
    this.controller,
    this.center = kMapCenter,
    this.zoom = 15.2,
    this.onZoneTap,
    this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        minZoom: 12,
        maxZoom: 18,
        backgroundColor: const Color(0xFFE9EEF3),
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
        onTap: onMapTap == null ? null : (tapPosition, point) => onMapTap!(),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.smarttraffic.smart_traffic',
        ),
        ListenableBuilder(
          listenable: app,
          builder: (context, child) => MarkerLayer(
            markers: [
              for (final z in app.zones)
                Marker(
                  point: z.pos,
                  width: 56,
                  height: 56,
                  child: GestureDetector(
                    onTap: onZoneTap == null ? null : () => onZoneTap!(z),
                    child: Container(
                      decoration: BoxDecoration(
                          color: z.color.withValues(alpha: 0.25),
                          shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: z.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(z.id,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomRight,
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }
}

class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  Widget _item(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: t(11, c: AppColors.muted)),
      ]);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _item(AppColors.green, 'Normal'),
          const SizedBox(width: 22),
          _item(AppColors.yellow, 'Moderate'),
          const SizedBox(width: 22),
          _item(AppColors.red, 'Heavy'),
        ],
      );
}

void showZoneSheet(BuildContext context, TrafficZone z) {
  showAppSheet(
    context,
    (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      child: ListenableBuilder(
        listenable: app,
        builder: (context, child) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                    child: Text('Zone ${z.name}',
                        style: t(17, w: FontWeight.w700))),
                Pill(z.status, bg: z.track, fg: AppColors.ink),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: z.load,
                minHeight: 6,
                backgroundColor: AppColors.grayChip,
                valueColor: AlwaysStoppedAnimation(z.color),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _Fact('Road load', '${(z.load * 100).round()}%')),
              Expanded(child: _Fact('Avg. speed', app.speedText(z.speedKmh))),
              Expanded(
                  child: _Fact('Camera',
                      (z.cameraId == null ? null : app.cameraById(z.cameraId!))?.channel ?? '—')),
            ]),
            const SizedBox(height: 20),
            PrimaryBtn('View camera', icon: Icons.videocam_outlined, onTap: () {
              Navigator.pop(ctx);
              final zc = z.cameraId == null ? null : app.cameraById(z.cameraId!);
              if (zc == null) {
                app.toast('Camera for this zone was removed');
                return;
              }
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => FullscreenCamera(cameraId: zc.id)));
            }),
          ],
        ),
      ),
    ),
  );
}

class _Fact extends StatelessWidget {
  final String k, v;
  const _Fact(this.k, this.v);
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: t(10.5, c: AppColors.muted)),
          const SizedBox(height: 4),
          Text(v, style: t(14, w: FontWeight.w700)),
        ],
      );
}

class MapPage extends StatefulWidget {
  final String? focusZoneId;
  const MapPage({super.key, this.focusZoneId});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mc = MapController();
  late final TrafficZone? _focus;

  @override
  void initState() {
    super.initState();
    _focus = widget.focusZoneId == null ? null : app.zoneById(widget.focusZoneId!);
    if (_focus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showZoneSheet(context, _focus!);
      });
    }
  }

  @override
  void dispose() {
    _mc.dispose();
    super.dispose();
  }

  void _fly(TrafficZone z) {
    _mc.move(z.pos, 16.4);
    showZoneSheet(context, z);
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Traffic map',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                ZoneMap(
                  controller: _mc,
                  center: _focus?.pos ?? kMapCenter,
                  zoom: _focus == null ? 15.2 : 16.4,
                  onZoneTap: _fly,
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: IconButton(
                      icon: const Icon(Icons.my_location, color: AppColors.blue),
                      onPressed: () => _mc.move(kMapCenter, 15.2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: SafeArea(
              top: false,
              child: ListenableBuilder(
                listenable: app,
                builder: (context, child) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MapLegend(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (final z in app.zones) ...[
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _fly(z),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: z.track.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Zone ${z.id}',
                                        style: t(12, w: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(z.status,
                                        style: t(11, c: AppColors.muted)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (z != app.zones.last) const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
