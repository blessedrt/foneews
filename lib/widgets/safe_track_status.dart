import 'package:flutter/material.dart';
import '../services/safe_track_service.dart';
import 'package:geolocator/geolocator.dart';

class SafeTrackStatus extends StatefulWidget {
  const SafeTrackStatus({Key? key}) : super(key: key);

  @override
  State<SafeTrackStatus> createState() => _SafeTrackStatusState();
}

class _SafeTrackStatusState extends State<SafeTrackStatus> {
  bool _isTracking = false;
  Position? _lastPosition;

  @override
  void initState() {
    super.initState();
    
    SafeTrackService.onTrackingStateChanged = (tracking) {
      if (mounted) setState(() => _isTracking = tracking);
    };
    
    SafeTrackService.onLocationUpdated = (position) {
      if (mounted) setState(() => _lastPosition = position);
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!_isTracking) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.location_on,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('SafeTrack ON',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: SafeTrackService.stopTracking,
                  child: const Text('Stop'),
                ),
              ],
            ),
            if (_lastPosition != null) ...[
              const SizedBox(height: 8),
              Text(
                'Location: ${_lastPosition!.latitude.toStringAsFixed(6)}, '
                '${_lastPosition!.longitude.toStringAsFixed(6)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    SafeTrackService.onTrackingStateChanged = null;
    SafeTrackService.onLocationUpdated = null;
    super.dispose();
  }
}