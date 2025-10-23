import 'dart:async';
import 'package:flutter/material.dart';
import '../services/wifi_service.dart';

class WiFiStatus extends StatefulWidget {
  const WiFiStatus({Key? key}) : super(key: key);

  @override
  State<WiFiStatus> createState() => _WiFiStatusState();
}

class _WiFiStatusState extends State<WiFiStatus> {
  String _status = 'Initializing...';
  StreamSubscription<String>? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _statusSubscription = WiFiService.statusController.stream.listen((status) {
      if (mounted) {
        setState(() => _status = status);
      }
    });
  }

  @override
void dispose() {
    _statusSubscription?.cancel();
    _statusSubscription = null;
    super.dispose();
}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              _getStatusIcon(),
              key: ValueKey(_getStatusIcon()),
              color: _getStatusColor(theme),
              size: 32,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Wi-Fi Status',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.8)
                  : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _status,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.6)
                  : Colors.black54,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    if (_status.contains('Ready') || _status.contains('online')) {
      return Icons.wifi;
    } else if (_status.contains('Searching') || _status.contains('Connecting')) {
      return Icons.wifi_find;
    } else if (_status.contains('off') || _status.contains('not in range')) {
      return Icons.wifi_off;
    } else {
      return Icons.wifi_tethering_error;
    }
  }

  Color _getStatusColor(ThemeData theme) {
    if (_status.contains('Ready') || _status.contains('online')) {
      return Colors.green;
    } else if (_status.contains('Searching') || _status.contains('Connecting')) {
      return Colors.orange;
    } else if (_status.contains('off') || _status.contains('not in range')) {
      return Colors.grey;
    } else {
      return theme.colorScheme.error;
    }
  }
}