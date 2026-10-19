import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/location_service.dart';

class GpsTestScreen extends StatefulWidget {
  const GpsTestScreen({super.key});

  @override
  State<GpsTestScreen> createState() => _GpsTestScreenState();
}

class _GpsTestScreenState extends State<GpsTestScreen> {
  Position? _position;

  LocationPermission _permission = LocationPermission.denied;

  bool _serviceEnabled = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final locationService = LocationService.instance;

      // Check whether device location service is enabled.
      final serviceEnabled =
          await locationService.isLocationServiceEnabled();

      // Check/request location permission.
      LocationPermission permission =
          await locationService.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await locationService.requestPermission();
      }

      // Stop if permission is permanently denied.
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        setState(() {
          _serviceEnabled = serviceEnabled;
          _permission = permission;
          _position = null;
          _errorMessage =
              'Location permission is permanently denied. '
              'Please enable it from browser/app settings.';
          _isLoading = false;
        });

        return;
      }

      // Stop if permission is denied.
      if (permission == LocationPermission.denied) {
        if (!mounted) return;

        setState(() {
          _serviceEnabled = serviceEnabled;
          _permission = permission;
          _position = null;
          _errorMessage = 'Location permission was denied.';
          _isLoading = false;
        });

        return;
      }

      // Get current GPS position.
      final position =
          await locationService.getCurrentPosition();

      if (!mounted) return;

      setState(() {
        _serviceEnabled = serviceEnabled;
        _permission = permission;
        _position = position;
        _isLoading = false;

        if (position == null) {
          _errorMessage =
              'Unable to retrieve the current GPS location.';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'GPS error: $e';
      });
    }
  }

  String _permissionText(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.denied:
        return 'Denied';

      case LocationPermission.deniedForever:
        return 'Permanently Denied';

      case LocationPermission.whileInUse:
        return 'While Using';

      case LocationPermission.always:
        return 'Always';

      case LocationPermission.unableToDetermine:
        return 'Unable to Determine';
    }
  }

  String _formatNumber(double value) {
    return value.toStringAsFixed(8);
  }

  String _formatAccuracy(double value) {
    return '${value.toStringAsFixed(2)} meters';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Location Test'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.location_on,
              size: 64,
            ),

            const SizedBox(height: 16),

            const Text(
              'GPS LOCATION TEST',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 24),

            _buildStatusCard(
              title: 'Location Service',
              value: _serviceEnabled
                  ? 'Enabled'
                  : 'Disabled',
              icon: Icons.gps_fixed,
            ),

            const SizedBox(height: 12),

            _buildStatusCard(
              title: 'Location Permission',
              value: _permissionText(_permission),
              icon: Icons.security,
            ),

            const SizedBox(height: 20),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Getting current GPS location...',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

            if (!_isLoading && _position != null)
              _buildLocationCard(_position!),

            if (!_isLoading && _errorMessage != null)
              _buildErrorCard(_errorMessage!),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _getLocation,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Location'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 30),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(Position position) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'CURRENT GPS LOCATION',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            _buildLocationRow(
              'Latitude',
              _formatNumber(position.latitude),
              Icons.north,
            ),

            const Divider(),

            _buildLocationRow(
              'Longitude',
              _formatNumber(position.longitude),
              Icons.east,
            ),

            const Divider(),

            _buildLocationRow(
              'Accuracy',
              _formatAccuracy(position.accuracy),
              Icons.my_location,
            ),

            const Divider(),

            _buildLocationRow(
              'Timestamp',
              position.timestamp.toLocal().toString(),
              Icons.access_time,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(
    String title,
    String value,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message),
            ),
          ],
        ),
      ),
    );
  }
}