import 'package:flutter/material.dart';
import 'package:foneews/services/notifications_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/location_service.dart';
import '../../services/weather_service.dart';
import '../../config.dart';
import '../../widgets/safe_track_status.dart';
import '../../services/wifi_service.dart';
import '../../widgets/wifi_status.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  LatLng _pos = const LatLng(-37.8136, 144.9631);
  String _temp = '--';
  String _cond = 'Loading...';
  GoogleMapController? _map;
  bool _ready = false; // Changed to false initially
  bool _mapCreated = false;
  

  @override
  void initState() {
    super.initState();
    WiFiService.setActivityVisible(true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSafe());
  }

  @override
  void dispose() {
    WiFiService.setActivityVisible(false);
    _map?.dispose();
    super.dispose();
  }

  Future<void> _loadSafe() async {
    try {
      debugPrint('🔄 Loading dashboard data...');
      
      // Get location first
      final loc = await LocationService.getLast()
          .timeout(const Duration(seconds: 10), onTimeout: () {
            debugPrint('⏱️ Location request timeout');
            return null;
          });

      if (!mounted) return;
      
      if (loc != null) {
        debugPrint('✅ Location obtained: ${loc.latitude}, ${loc.longitude}');
        setState(() {
          _pos = LatLng(loc.latitude, loc.longitude);
        });
        
        // Move camera if map is ready
        if (_mapCreated) {
          await _map?.animateCamera(CameraUpdate.newLatLng(_pos));
        }
      } else {
        debugPrint('⚠️ Using default location (Melbourne)');
      }

      // Get weather
      final w = await WeatherService.current(_pos.latitude, _pos.longitude)
          .timeout(const Duration(seconds: 10),
              onTimeout: () {
                debugPrint('⏱️ Weather request timeout');
                return WeatherNow(22, 'Partly Cloudy (Demo)');
              });

      if (!mounted) return;
      setState(() {
        _temp = '${w.tempC}°C';
        _cond = w.condition;
        _ready = true;
      });
      
      debugPrint('✅ Dashboard loaded successfully');
    } catch (e, st) {
      debugPrint('❌ Dashboard load failed: $e\n$st');
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
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      floatingActionButton: _buildSOSButton(),
      body: Stack(
        children: [
          // Background map
          _mapWidgetOrPlaceholder(),
          
          // Gradient overlay for better readability
          const _GradientOverlay(),
          
          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  _buildHeader(theme),
                  const SizedBox(height: 24),
                  
                  // Status cards row
                  _buildStatusRow(),
                  const SizedBox(height: 16),
                  
                  // Weather card
                  _buildWeatherCard(theme),
                  
                  // Spacer to push SafeTrack to bottom
                  const Spacer(),
                  
                  // SafeTrack status
                  const SafeTrackStatus(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FOneEWS',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Dashboard',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
        if (AppConfig.mockMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.secondary.withOpacity(0.3),
              ),
            ),
            child: Text(
              'MOCK MODE',
              style: TextStyle(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusRow() {
    return Row(
      children: [
        Expanded(child: _buildStatusCard('BLE', Icons.bluetooth)),
        const SizedBox(width: 12),
        const Expanded(child: WiFiStatus()),
        const SizedBox(width: 12),
        Expanded(child: _buildStatusCard('Internet', Icons.cloud)),
      ],
    );
  }


  Widget _buildStatusCard(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.wb_sunny_outlined,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Weather',
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadSafe,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  _temp,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    _cond,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSOSButton() {
    return FloatingActionButton.extended(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SOS sent')),
        );
      },
      icon: const Icon(Icons.warning_amber_rounded),
      label: const Text('SOS'),
    );
  }

  Widget _buildTestButton() {
    return FloatingActionButton(
      onPressed: () async {
        await Noti.showTest();
      },
      tooltip: 'Test Notification',
      child: Icon(Icons.notifications_active),
    );
  }

  Widget _mapWidgetOrPlaceholder() {
    if (!_ready) {
      return Container(
        color: Theme.of(context).colorScheme.surface,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: _pos, zoom: 14),
      onMapCreated: (controller) {
        debugPrint('🗺️ Map created');
        _map = controller;
        _mapCreated = true;
        // Move to current position after map is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          _map?.animateCamera(CameraUpdate.newLatLng(_pos));
        });
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      markers: {
        Marker(
          markerId: const MarkerId('current'),
          position: _pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        )
      },
      mapType: MapType.normal,
      zoomControlsEnabled: false,
      padding: const EdgeInsets.only(bottom: 100),
      minMaxZoomPreference: const MinMaxZoomPreference(5, 20),
    );
  }
}

class _GradientOverlay extends StatelessWidget {
  const _GradientOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [
                Colors.black.withOpacity(0.7),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}