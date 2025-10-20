// lib/features/dashboard/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/location_service.dart';
import '../../services/weather_service.dart';
import '../../config.dart'; // for mock mode chip

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  LatLng _pos = const LatLng(-37.8136, 144.9631); // Melbourne default
  String _temp = '--';
  String _cond = 'Loading...';
  GoogleMapController? _map;
  bool _ready = false; // flip true after first async finishes

  @override
  void initState() {
    super.initState();
    // ✅ Do not run async in initState directly; defer until first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSafe());
  }

  Future<void> _loadSafe() async {
    try {
      // Location with timeout (won’t block UI)
      final loc = await LocationService.getLast()
          .timeout(const Duration(seconds: 5), onTimeout: () => null);

      if (!mounted) return;
      if (loc != null) {
        _pos = LatLng(loc.latitude, loc.longitude);
        setState(() {}); // move marker/camera
        _map?.moveCamera(CameraUpdate.newLatLng(_pos));
      }

      // Weather with timeout + safe fallback (mock or demo)
      final w = await WeatherService.current(_pos.latitude, _pos.longitude)
          .timeout(const Duration(seconds: 5), onTimeout: () => WeatherNow(22, 'Partly Cloudy (Demo)'));

      if (!mounted) return;
      setState(() {
        _temp = '${w.tempC}°C';
        _cond = w.condition;
        _ready = true;
      });
    } catch (e, st) {
      debugPrint('Dashboard load failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _temp = '22°C';
        _cond = 'Partly Cloudy (Demo)';
        _ready = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Theme.of(context).colorScheme.error,
        label: const Text('SOS'),
        onPressed: () {
          // In mock mode this should be instant/no-op
          // call your MQTT SOS here if live
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SOS sent (mock)')),
          );
        },
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('FOneEWS — Dashboard', style: Theme.of(context).textTheme.titleLarge),
                if (AppConfig.mockMode) const Chip(label: Text('Mock mode')),
              ]),
              const SizedBox(height: 8),
              // Receiver status chips
              const Row(children: [
                _StatusChip('BLE'), SizedBox(width: 8),
                _StatusChip('Wi-Fi'), SizedBox(width: 8),
                _StatusChip('Internet'),
              ]),
              const SizedBox(height: 12),
              // Weather card
              Card(
                child: ListTile(
                  title: const Text('Weather'),
                  subtitle: Text('$_temp  •  $_cond'),
                  trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSafe),
                ),
              ),
              const SizedBox(height: 12),
              // Map (placeholder until ready, to prove UI renders)
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _mapWidgetOrPlaceholder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mapWidgetOrPlaceholder() {
    // Show placeholder immediately; swap to map when controller is available
    if (!_ready) {
      return const ColoredBox(
        color: Color(0x11000000),
        child: Center(child: Text('Loading map…')),
      );
    }
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: _pos, zoom: 12),
      onMapCreated: (c) {
        _map = c;
        // small post-create camera nudge
        Future.microtask(() => _map?.moveCamera(CameraUpdate.newLatLng(_pos)));
      },
      myLocationEnabled: true,
      markers: { Marker(markerId: const MarkerId('me'), position: _pos) },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  const _StatusChip(this.label);
  @override
  Widget build(BuildContext context) => Chip(label: Text(label));
}
