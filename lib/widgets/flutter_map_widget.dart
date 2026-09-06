import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:mbtiles/mbtiles.dart';
import 'package:latlong2/latlong.dart';
import '../utils/mbtiles_helper.dart';
import 'dart:math' as math;
import '../models/rover_status.dart';

class FlutterMapWidget extends StatefulWidget {
  final RoverStatus status;
  final bool ikutiRover;
  final ValueChanged<bool> onIkutiRoverChanged;

  const FlutterMapWidget({
    Key? key,
    required this.status,
    required this.ikutiRover,
    required this.onIkutiRoverChanged,
  }) : super(key: key);

  @override
  _FlutterMapWidgetState createState() => _FlutterMapWidgetState();
}

class _FlutterMapWidgetState extends State<FlutterMapWidget> {
  final MapController _mapController = MapController();
  MbTiles? _mbTiles;

  @override
  void initState() {
    super.initState();
    _loadMbTiles();
  }

  Future<void> _loadMbTiles() async {
    try {
      final path = await MbTilesHelper.getMbTilesPath();
      setState(() {
        _mbTiles = MbTiles(mbtilesPath: path);
      });
    } catch (e) {
      debugPrint('Error loading MBTiles: $e');
    }
  }

  @override
  void dispose() {
    _mbTiles?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FlutterMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ikutiRover && !oldWidget.ikutiRover) {
      _centerOnRover();
    } else if (widget.ikutiRover && (oldWidget.status.lat != widget.status.lat || oldWidget.status.lng != widget.status.lng)) {
      _centerOnRover();
    }
  }

  void _centerOnRover() {
    if (widget.status.lat != 0 && widget.status.lng != 0) {
      _mapController.move(LatLng(widget.status.lat, widget.status.lng), _mapController.camera.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roverPos = LatLng(
      widget.status.lat != 0 ? widget.status.lat : -7.9285, 
      widget.status.lng != 0 ? widget.status.lng : 110.3805
    );

    return _mbTiles == null 
      ? const Center(child: CircularProgressIndicator())
      : FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: roverPos,
        initialZoom: 16.5,
        maxZoom: 22.0,
        onPositionChanged: (position, hasGesture) {
          if (hasGesture && widget.ikutiRover) {
            widget.onIkutiRoverChanged(false);
          }
        },
      ),
      children: [
        TileLayer(
          tileProvider: MbTilesTileProvider(mbtiles: _mbTiles!),
          maxNativeZoom: 16,
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: widget.status.waypoints.map((w) => LatLng(w.lat, w.lng)).toList(),
              strokeWidth: 4.0,
              color: Colors.blue,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            // Waypoints
            ...widget.status.waypoints.map((w) => Marker(
              point: LatLng(w.lat, w.lng),
              width: 12,
              height: 12,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            )),
            // Rover Position
            Marker(
              point: roverPos,
              width: 40,
              height: 40,
              child: Transform.rotate(
                angle: widget.status.heading * (math.pi / 180),
                child: const Icon(
                  Icons.navigation,
                  color: Colors.orange,
                  size: 40,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
