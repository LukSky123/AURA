import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../domain.dart';
import '../theme/aura_theme.dart';

class MapTab extends StatefulWidget {
  const MapTab({
    super.key,
    required this.currentPosition,
    required this.incidents,
    required this.onRequestLocation,
  });

  final Position? currentPosition;
  final List<Incident> incidents;
  final Future<void> Function() onRequestLocation;

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final MapController _mapController = MapController();

  LatLng get _currentLatLng {
    if (widget.currentPosition != null) {
      return LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude);
    }
    // Default to Lagos coordinates
    return const LatLng(6.5244, 3.3792);
  }

  void _recenter() {
    _mapController.move(_currentLatLng, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    final latLng = _currentLatLng;
    final pos = widget.currentPosition;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: latLng,
            initialZoom: 14.5,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.aura.safety',
            ),
            // User Location Pulse & Marker
            CircleLayer(
              circles: [
                CircleMarker(
                  point: latLng,
                  radius: pos?.accuracy ?? 35,
                  useRadiusInMeter: true,
                  color: AuraColors.cyan.withValues(alpha: 0.15),
                  borderColor: AuraColors.cyan,
                  borderStrokeWidth: 1.5,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: latLng,
                  width: 32,
                  height: 32,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AuraColors.cyan,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AuraColors.cyan.withValues(alpha: 0.8),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.my_location, color: AuraColors.background, size: 18),
                  ),
                ),
                // Recent Incident Markers
                ...widget.incidents.where((i) => i.latitude != null && i.longitude != null).map((i) {
                  return Marker(
                    point: LatLng(i.latitude!, i.longitude!),
                    width: 36,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AuraColors.crimson,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AuraColors.crimson.withValues(alpha: 0.7),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.warning_rounded, color: Colors.white, size: 20),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),

        // Dark gradient vignette overlay for technical aesthetic
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AuraColors.background.withValues(alpha: 0.5),
                  Colors.transparent,
                  Colors.transparent,
                  AuraColors.background.withValues(alpha: 0.7),
                ],
                stops: const [0.0, 0.15, 0.8, 1.0],
              ),
            ),
          ),
        ),

        // Floating Coordinates & Status Card
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AuraColors.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AuraColors.cyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.satellite_alt_rounded, color: AuraColors.cyan, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Live Coordinate Fix',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pos != null
                            ? ',  (±m)'
                            : 'Waiting for GPS fix (Offline cache active)',
                        style: const TextStyle(
                          color: AuraColors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AuraColors.cyan, size: 20),
                  onPressed: () async {
                    await widget.onRequestLocation();
                    _recenter();
                  },
                ),
              ],
            ),
          ),
        ),

        // Floating Recenter Button
        Positioned(
          bottom: 24,
          right: 20,
          child: FloatingActionButton.small(
            onPressed: _recenter,
            backgroundColor: AuraColors.surface,
            foregroundColor: AuraColors.cyan,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}
