import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../services/location_service.dart';

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  final MapController _mapController = MapController();

  final LocationService _locationService =
      LocationService.instance;

  Position? _currentPosition;

  LocationPermission _permission =
      LocationPermission.denied;

  bool _serviceEnabled = false;
  bool _isLoading = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  // ============================================================
  // LOAD CURRENT LOCATION
  // ============================================================

  Future<void> _loadLocation({
    bool moveMap = true,
  }) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ----------------------------------------------------------
      // CHECK LOCATION SERVICE
      // ----------------------------------------------------------

      final serviceEnabled =
          await _locationService.isLocationServiceEnabled();

      // ----------------------------------------------------------
      // CHECK LOCATION PERMISSION
      // ----------------------------------------------------------

      LocationPermission permission =
          await _locationService.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
            await _locationService.requestPermission();
      }

      if (!mounted) return;

      setState(() {
        _serviceEnabled = serviceEnabled;
        _permission = permission;
      });

      // ----------------------------------------------------------
      // LOCATION SERVICE DISABLED
      // ----------------------------------------------------------

      if (!serviceEnabled) {
        setState(() {
          _currentPosition = null;
          _errorMessage =
              'Location service is disabled. Please enable GPS/location services.';
          _isLoading = false;
        });

        return;
      }

      // ----------------------------------------------------------
      // PERMISSION DENIED
      // ----------------------------------------------------------

      if (permission == LocationPermission.denied) {
        setState(() {
          _currentPosition = null;
          _errorMessage =
              'Location permission was denied. Please allow location access.';
          _isLoading = false;
        });

        return;
      }

      // ----------------------------------------------------------
      // PERMISSION PERMANENTLY DENIED
      // ----------------------------------------------------------

      if (permission ==
          LocationPermission.deniedForever) {
        setState(() {
          _currentPosition = null;
          _errorMessage =
              'Location permission is permanently denied. '
              'Please enable location permission from browser or device settings.';
          _isLoading = false;
        });

        return;
      }

      // ----------------------------------------------------------
      // GET CURRENT POSITION
      // ----------------------------------------------------------

      final position =
          await _locationService.getCurrentPosition();

      if (!mounted) return;

      if (position == null) {
        setState(() {
          _currentPosition = null;
          _errorMessage =
              'Unable to retrieve your current location.';
          _isLoading = false;
        });

        return;
      }

      // ----------------------------------------------------------
      // UPDATE LOCATION
      // ----------------------------------------------------------

      setState(() {
        _currentPosition = position;
        _isLoading = false;
        _errorMessage = null;
      });

      if (moveMap) {
        _moveMapToPosition(position);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to get your current location.';
      });

      debugPrint(
        'MAP LOCATION ERROR: $e',
      );
    }
  }

  // ============================================================
  // MOVE MAP TO LOCATION
  // ============================================================

  void _moveMapToPosition(Position position) {
    try {
      _mapController.move(
        LatLng(
          position.latitude,
          position.longitude,
        ),
        16.0,
      );
    } catch (e) {
      debugPrint(
        'MAP MOVE ERROR: $e',
      );
    }
  }

  // ============================================================
  // MY LOCATION
  // ============================================================

  Future<void> _goToMyLocation() async {
    if (_currentPosition == null) {
      await _loadLocation();
      return;
    }

    _moveMapToPosition(
      _currentPosition!,
    );
  }

  // ============================================================
  // LOCATION SETTINGS
  // ============================================================

  Future<void> _openLocationSettings() async {
    try {
      if (_permission ==
          LocationPermission.deniedForever) {
        await _locationService.openAppSettings();
      } else {
        await _locationService.openLocationSettings();
      }
    } catch (e) {
      debugPrint(
        'LOCATION SETTINGS ERROR: $e',
      );
    }
  }

  // ============================================================
  // FORMAT COORDINATE
  // ============================================================

  String _formatCoordinate(double value) {
    return value.toStringAsFixed(8);
  }

  // ============================================================
  // FORMAT ACCURACY
  // ============================================================

  String _formatAccuracy(double value) {
    return '${value.toStringAsFixed(2)} m';
  }

  // ============================================================
  // PERMISSION TEXT
  // ============================================================

  String _permissionText(
    LocationPermission permission,
  ) {
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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF0B1220),

      appBar: AppBar(
        backgroundColor:
            const Color(0xFF111827),

        foregroundColor:
            Colors.white,

        elevation: 0,

        title: const Text(
          'Maps & Location',
          style: TextStyle(
            fontWeight:
                FontWeight.w700,
          ),
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh Location',

            onPressed: _isLoading
                ? null
                : () => _loadLocation(),

            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [

            // ======================================================
            // MAP
            // ======================================================

            Expanded(
              flex: 6,
              child: _buildMap(),
            ),

            // ======================================================
            // LOCATION INFORMATION
            // ======================================================

            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.all(16),

                child: Column(
                  children: [

                    _buildLocationStatus(),

                    const SizedBox(
                      height: 12,
                    ),

                    if (_currentPosition != null)
                      _buildCurrentLocationCard(),

                    if (_errorMessage != null)
                      Padding(
                        padding:
                            const EdgeInsets.only(
                          top: 12,
                        ),
                        child:
                            _buildErrorCard(),
                      ),

                    const SizedBox(
                      height: 12,
                    ),

                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MAP
  // ============================================================

  Widget _buildMap() {
    final Position? position =
        _currentPosition;

    final LatLng center =
        position != null
            ? LatLng(
                position.latitude,
                position.longitude,
              )
            : const LatLng(
                17.3850,
                78.4867,
              );

    return Stack(
      children: [

        FlutterMap(
          mapController:
              _mapController,

          options: MapOptions(
            initialCenter:
                center,

            initialZoom:
                position != null
                    ? 16.0
                    : 5.0,

            minZoom: 2.0,

            maxZoom: 19.0,
          ),

          children: [

            // ------------------------------------------------------
            // OPENSTREETMAP
            // ------------------------------------------------------

            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

              userAgentPackageName:
                  'com.driversafetyai.app',
            ),

            // ------------------------------------------------------
            // CURRENT LOCATION MARKER
            // ------------------------------------------------------

            if (position != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(
                      position.latitude,
                      position.longitude,
                    ),

                    width: 55,

                    height: 55,

                    child: Container(
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.blue
                                .withOpacity(
                          0.18,
                        ),

                        shape:
                            BoxShape.circle,
                      ),

                      child: Center(
                        child: Container(
                          width: 22,
                          height: 22,

                          decoration:
                              BoxDecoration(
                            color:
                                Colors.blue,

                            shape:
                                BoxShape.circle,

                            border:
                                Border.all(
                              color:
                                  Colors.white,
                              width: 3,
                            ),

                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black
                                        .withOpacity(
                                  0.35,
                                ),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),

        // ========================================================
        // LOADING OVERLAY
        // ========================================================

        if (_isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black
                  .withOpacity(0.35),

              child: const Center(
                child:
                    CircularProgressIndicator(),
              ),
            ),
          ),

        // ========================================================
        // MY LOCATION BUTTON
        // ========================================================

        Positioned(
          right: 16,
          bottom: 16,

          child:
              FloatingActionButton(
            heroTag:
                'maps_my_location_button',

            backgroundColor:
                Colors.white,

            foregroundColor:
                const Color(0xFF2563EB),

            tooltip:
                'My Current Location',

            onPressed:
                _goToMyLocation,

            child: const Icon(
              Icons.my_location_rounded,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // LOCATION STATUS
  // ============================================================

  Widget _buildLocationStatus() {
    final bool permissionGranted =
        _permission ==
                LocationPermission
                    .whileInUse ||
            _permission ==
                LocationPermission
                    .always;

    return Container(
      padding:
          const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color:
            const Color(0xFF111827),

        borderRadius:
            BorderRadius.circular(16),

        border: Border.all(
          color:
              Colors.white.withOpacity(
            0.08,
          ),
        ),
      ),

      child: Column(
        children: [

          // ------------------------------------------------------
          // GPS SERVICE
          // ------------------------------------------------------

          Row(
            children: [

              _buildStatusIcon(
                enabled:
                    _serviceEnabled,
                icon:
                    Icons.gps_fixed_rounded,
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                  children: [

                    const Text(
                      'GPS / Location Service',
                      style: TextStyle(
                        color:
                            Colors.white,
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      _serviceEnabled
                          ? 'Enabled'
                          : 'Disabled',

                      style: TextStyle(
                        color:
                            _serviceEnabled
                                ? Colors.green
                                : Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          Divider(
            color:
                Colors.white.withOpacity(
              0.08,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          // ------------------------------------------------------
          // PERMISSION
          // ------------------------------------------------------

          Row(
            children: [

              _buildStatusIcon(
                enabled:
                    permissionGranted,
                icon:
                    Icons.security_rounded,
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                  children: [

                    const Text(
                      'Location Permission',
                      style: TextStyle(
                        color:
                            Colors.white,
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      _permissionText(
                        _permission,
                      ),

                      style: TextStyle(
                        color:
                            permissionGranted
                                ? Colors.green
                                : Colors.orange,

                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS ICON
  // ============================================================

  Widget _buildStatusIcon({
    required bool enabled,
    required IconData icon,
  }) {
    return Container(
      width: 42,
      height: 42,

      decoration: BoxDecoration(
        color: enabled
            ? Colors.green
                .withOpacity(0.12)
            : Colors.red
                .withOpacity(0.12),

        borderRadius:
            BorderRadius.circular(12),
      ),

      child: Icon(
        icon,

        color: enabled
            ? Colors.green
            : Colors.redAccent,

        size: 21,
      ),
    );
  }

  // ============================================================
  // CURRENT LOCATION CARD
  // ============================================================

  Widget _buildCurrentLocationCard() {
    final position =
        _currentPosition!;

    return Container(
      padding:
          const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color:
            const Color(0xFF111827),

        borderRadius:
            BorderRadius.circular(16),

        border: Border.all(
          color:
              Colors.white.withOpacity(
            0.08,
          ),
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          Row(
            children: [

              Container(
                width: 42,
                height: 42,

                decoration:
                    BoxDecoration(
                  color: Colors.blue
                      .withOpacity(
                    0.12,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),

                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.blue,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Text(
                      'Current Location',
                      style: TextStyle(
                        color:
                            Colors.white,
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    SizedBox(
                      height: 3,
                    ),

                    Text(
                      'Your current GPS position',
                      style: TextStyle(
                        color:
                            Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),

                decoration:
                    BoxDecoration(
                  color: Colors.green
                      .withOpacity(
                    0.12,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),

                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color:
                        Colors.green,
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 18,
          ),

          _buildCoordinateRow(
            icon:
                Icons.north_rounded,
            title:
                'Latitude',
            value:
                _formatCoordinate(
              position.latitude,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          _buildCoordinateRow(
            icon:
                Icons.east_rounded,
            title:
                'Longitude',
            value:
                _formatCoordinate(
              position.longitude,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          _buildCoordinateRow(
            icon:
                Icons.gps_fixed_rounded,
            title:
                'Accuracy',
            value:
                _formatAccuracy(
              position.accuracy,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          _buildCoordinateRow(
            icon:
                Icons.access_time_rounded,
            title:
                'Updated',
            value:
                _formatTime(
              position.timestamp,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COORDINATE ROW
  // ============================================================

  Widget _buildCoordinateRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [

        Icon(
          icon,
          color:
              Colors.white54,
          size: 18,
        ),

        const SizedBox(
          width: 10,
        ),

        SizedBox(
          width: 75,

          child: Text(
            title,

            style:
                const TextStyle(
              color:
                  Colors.white60,
              fontSize: 12,
            ),
          ),
        ),

        Expanded(
          child: SelectableText(
            value,

            style:
                const TextStyle(
              color:
                  Colors.white,
              fontSize: 12,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TIME
  // ============================================================

  String _formatTime(
    DateTime? timestamp,
  ) {
    if (timestamp == null) {
      return 'Not available';
    }

    final localTime =
        timestamp.toLocal();

    final hour =
        localTime.hour
            .toString()
            .padLeft(
              2,
              '0',
            );

    final minute =
        localTime.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    final second =
        localTime.second
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '$hour:$minute:$second';
  }

  // ============================================================
  // ERROR CARD
  // ============================================================

  Widget _buildErrorCard() {
    return Container(
      padding:
          const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color:
            Colors.redAccent
                .withOpacity(0.08),

        borderRadius:
            BorderRadius.circular(14),

        border: Border.all(
          color: Colors.redAccent
              .withOpacity(0.25),
        ),
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          const Icon(
            Icons.warning_amber_rounded,
            color:
                Colors.redAccent,
            size: 22,
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Text(
              _errorMessage!,

              style:
                  const TextStyle(
                color:
                    Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTION BUTTONS
  // ============================================================

  Widget _buildActionButtons() {
    return Column(
      children: [

        // --------------------------------------------------------
        // REFRESH LOCATION
        // --------------------------------------------------------

        SizedBox(
          width:
              double.infinity,

          height: 50,

          child:
              ElevatedButton.icon(
            onPressed: _isLoading
                ? null
                : () => _loadLocation(),

            icon: const Icon(
              Icons.refresh_rounded,
            ),

            label: const Text(
              'Refresh Location',
            ),

            style:
                ElevatedButton.styleFrom(
              backgroundColor:
                  const Color(
                0xFF2563EB,
              ),

              foregroundColor:
                  Colors.white,

              disabledBackgroundColor:
                  Colors.blue
                      .withOpacity(
                0.35,
              ),

              elevation: 0,

              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(
          height: 10,
        ),

        // --------------------------------------------------------
        // LOCATION SETTINGS
        // --------------------------------------------------------

        if (!_serviceEnabled ||
            _permission ==
                LocationPermission
                    .deniedForever ||
            _permission ==
                LocationPermission
                    .denied)
          SizedBox(
            width:
                double.infinity,

            height: 48,

            child:
                OutlinedButton.icon(
              onPressed:
                  _openLocationSettings,

              icon: const Icon(
                Icons.settings_rounded,
              ),

              label: const Text(
                'Open Location Settings',
              ),

              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    Colors.white,

                side: BorderSide(
                  color: Colors.white
                      .withOpacity(
                    0.15,
                  ),
                ),

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}