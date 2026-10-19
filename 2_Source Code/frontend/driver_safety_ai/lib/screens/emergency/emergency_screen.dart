import 'package:flutter/material.dart';

import 'package:geolocator/geolocator.dart';



import '../../services/location_service.dart';

import '../../services/api_service.dart';



class EmergencyScreen extends StatefulWidget {

  final String accountId;



  const EmergencyScreen({

    super.key,

    required this.accountId,

  });



  @override

  State<EmergencyScreen> createState() =>

      _EmergencyScreenState();

}



class _EmergencyScreenState extends State<EmergencyScreen> {

  // ---------------------------------------------------------------------------

  // EMERGENCY CONTACT

  // ---------------------------------------------------------------------------



  String _emergencyContactName = '';

  String _emergencyContactPhone = '';

  String _emergencyContactEmail = '';

  String _emergencyContactRelationship = '';



  bool _isLoadingContact = false;



  String? _contactError;



  // ---------------------------------------------------------------------------

  // LOCATION

  // ---------------------------------------------------------------------------



  Position? _currentPosition;



  bool _isGettingLocation = false;

  bool _isSendingEmergency = false;



  String? _locationError;



  // ---------------------------------------------------------------------------

  // INIT

  // ---------------------------------------------------------------------------



  @override

  void initState() {

    super.initState();



    _loadEmergencyContact();

    _loadCurrentLocation();

  }



  // ---------------------------------------------------------------------------

  // LOAD EMERGENCY CONTACT FROM BACKEND

  // ---------------------------------------------------------------------------



  Future<void> _loadEmergencyContact() async {

    if (!mounted) return;



    if (widget.accountId.trim().isEmpty) {

      setState(() {

        _contactError =

            'Account ID is not available.';

      });



      return;

    }



    setState(() {

      _isLoadingContact = true;

      _contactError = null;

    });



    try {

      debugPrint(

        'Loading emergency contact for account: '

        '${widget.accountId}',

      );



      final result =

          await ApiService.getEmergencyContact(

        accountId: widget.accountId,

      );



      if (!mounted) return;



      if (result['success'] == true) {

        final contact =

            result['emergency_contact'];



        if (contact is Map) {

          setState(() {

            _emergencyContactName =

                contact['name']?.toString() ?? '';



            _emergencyContactPhone =

                contact['phone']?.toString() ?? '';



            _emergencyContactEmail =

                contact['email']?.toString() ?? '';



            _emergencyContactRelationship =

                contact['relationship']?.toString() ?? '';



            _isLoadingContact = false;

            _contactError = null;

          });



          debugPrint(

            'Emergency contact loaded successfully.',

          );



          debugPrint(

            'Emergency contact name: '

            '$_emergencyContactName',

          );



          debugPrint(

            'Emergency contact email: '

            '$_emergencyContactEmail',

          );

        } else {

          setState(() {

            _isLoadingContact = false;

            _contactError =

                'Emergency contact data is unavailable.';

          });

        }

      } else {

        setState(() {

          _isLoadingContact = false;

          _contactError =

              result['message']?.toString() ??

              'Unable to load emergency contact.';

        });

      }

    } catch (e) {

      if (!mounted) return;



      setState(() {

        _isLoadingContact = false;

        _contactError =

            'Emergency contact error: $e';

      });



      debugPrint(

        'Emergency contact exception: $e',

      );

    }

  }



  // ---------------------------------------------------------------------------

  // GET CURRENT LOCATION

  // ---------------------------------------------------------------------------



  Future<void> _loadCurrentLocation() async {

    if (!mounted) return;



    setState(() {

      _isGettingLocation = true;

      _locationError = null;

    });



    try {

      final locationService =

          LocationService.instance;



      final serviceEnabled =

          await locationService

              .isLocationServiceEnabled();



      if (!serviceEnabled) {

        if (!mounted) return;



        setState(() {

          _isGettingLocation = false;

          _locationError =

              'Location service is disabled. '

              'Please enable location services.';

        });



        return;

      }



      var permission =

          await locationService.checkPermission();



      if (permission ==

          LocationPermission.denied) {

        permission =

            await locationService.requestPermission();

      }



      if (permission ==

          LocationPermission.denied) {

        if (!mounted) return;



        setState(() {

          _isGettingLocation = false;

          _locationError =

              'Location permission was denied.';

        });



        return;

      }



      if (permission ==

          LocationPermission.deniedForever) {

        if (!mounted) return;



        setState(() {

          _isGettingLocation = false;

          _locationError =

              'Location permission is permanently denied. '

              'Please enable it from browser/app settings.';

        });



        return;

      }



      final position =

          await locationService.getCurrentPosition();



      if (!mounted) return;



      if (position == null) {

        setState(() {

          _isGettingLocation = false;

          _locationError =

              'Unable to retrieve the current GPS location.';

        });



        return;

      }



      setState(() {

        _currentPosition = position;

        _isGettingLocation = false;

        _locationError = null;

      });

    } catch (e) {

      if (!mounted) return;



      setState(() {

        _isGettingLocation = false;

        _locationError =

            'Location error: $e';

      });

    }

  }



  // ---------------------------------------------------------------------------

  // LOCATION LINK

  // ---------------------------------------------------------------------------



  String _getLocationLink() {

    final position = _currentPosition;



    if (position == null) {

      return 'Location unavailable';

    }



    final latitude = position.latitude;

    final longitude = position.longitude;



    return 'https\://www\.google.com/maps/search/'

        '?api=1&query=$latitude,$longitude';

  }



  // ---------------------------------------------------------------------------

  // LOCATION TEXT

  // ---------------------------------------------------------------------------



  String _getLocationText() {

    final position = _currentPosition;



    if (position == null) {

      return 'Location unavailable';

    }



    return 'Latitude: '

        '${position.latitude.toStringAsFixed(6)}\n'

        'Longitude: '

        '${position.longitude.toStringAsFixed(6)}\n'

        'Accuracy: '

        '${position.accuracy.toStringAsFixed(2)} meters';

  }



  // ---------------------------------------------------------------------------

  // SOS CONFIRMATION

  // ---------------------------------------------------------------------------



  void _showSOSConfirmation(

    BuildContext context,

  ) {

    showDialog(

      context: context,

      builder: (dialogContext) {

        return AlertDialog(

          backgroundColor:

              const Color(0xFF1B2A41),



          title: const Row(

            children: [

              Icon(

                Icons.warning_amber_rounded,

                color: Colors.redAccent,

              ),



              SizedBox(width: 10),



              Expanded(

                child: Text(

                  "Activate SOS?",

                  style: TextStyle(

                    color: Colors.white,

                    fontWeight: FontWeight.bold,

                  ),

                ),

              ),

            ],

          ),



          content: Text(

            _currentPosition == null

                ? "Your current location is not available. "

                  "Do you still want to prepare the emergency email?"

                : "An emergency email will be prepared "

                  "with your current GPS location.",

            style: const TextStyle(

              color: Colors.white70,

              height: 1.4,

            ),

          ),



          actions: [

            TextButton(

              onPressed: () {

                Navigator.pop(dialogContext);

              },

              child: const Text(

                "CANCEL",

                style: TextStyle(

                  color: Colors.white70,

                ),

              ),

            ),



            ElevatedButton(

              onPressed: () {

                Navigator.pop(dialogContext);



                _sendEmergencyEmail(context);

              },



              style: ElevatedButton.styleFrom(

                backgroundColor:

                    Colors.redAccent,

                foregroundColor: Colors.white,

              ),



              child: const Text(

                "ACTIVATE",

              ),

            ),

          ],

        );

      },

    );

  }



  // ---------------------------------------------------------------------------

  // SEND EMERGENCY EMAIL

  // ---------------------------------------------------------------------------



  Future<void> _sendEmergencyEmail(
    BuildContext context,
  ) async {
    if (_isSendingEmergency) {
      return;
    }

    if (_emergencyContactEmail.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Emergency contact email is not available.",
            ),
          ),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSendingEmergency = true;
      });
    }

    try {
      await _loadCurrentLocation();

      final position = _currentPosition;
      final locationLink = _getLocationLink();
      final timestamp = DateTime.now().toLocal().toString();

      final latitude = position == null
          ? ''
          : position.latitude.toStringAsFixed(6);

      final longitude = position == null
          ? ''
          : position.longitude.toStringAsFixed(6);

      final accuracy = position == null
          ? ''
          : position.accuracy.toStringAsFixed(2);

      debugPrint(
        'Sending emergency alert through backend...',
      );
      debugPrint(
        'Account ID: ${widget.accountId}',
      );
      debugPrint(
        'Emergency contact email: $_emergencyContactEmail',
      );

      final result = await ApiService.sendEmergencyAlert(
        accountId: widget.accountId,
        status: 'MANUAL SOS ACTIVATED',
        timestamp: timestamp,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        googleMapsLink: locationLink,
        alertMessage:
            'The driver has activated the emergency SOS system.',
      );

      if (!context.mounted) {
        return;
      }

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Emergency alert email sent successfully.",
            ),
            backgroundColor: Colors.green,
          ),
        );

        debugPrint(
          'Emergency alert email sent successfully.',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ??
                  'Unable to send emergency alert email.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );

        debugPrint(
          'Emergency alert email failed: '
          '${result['message']}',
        );
      }
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      debugPrint(
        'Emergency alert error: $e',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Emergency email error: $e",
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingEmergency = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------

  // BUILD

  // ---------------------------------------------------------------------------



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:

          const Color(0xFF08111F),



      appBar: AppBar(

        backgroundColor:

            const Color(0xFF08111F),

        elevation: 0,

        foregroundColor: Colors.white,



        title: const Text(

          "Emergency SOS",

          style: TextStyle(

            fontWeight: FontWeight.bold,

          ),

        ),



        actions: [

          IconButton(

            tooltip: "Refresh emergency contact",

            onPressed: _isLoadingContact

                ? null

                : _loadEmergencyContact,

            icon: const Icon(

              Icons.refresh,

            ),

          ),

        ],

      ),



      body: SafeArea(

        child: SingleChildScrollView(

          padding: const EdgeInsets.all(24),



          child: Column(

            children: [

              const SizedBox(height: 30),



              // ================================================================

              // SOS ICON

              // ================================================================



              Container(

                width: 130,

                height: 130,



                decoration: BoxDecoration(

                  shape: BoxShape.circle,

                  color: Colors.redAccent

                      .withOpacity(0.12),



                  border: Border.all(

                    color: Colors.redAccent

                        .withOpacity(0.5),

                    width: 2,

                  ),

                ),



                child: const Icon(

                  Icons.sos_rounded,

                  size: 70,

                  color: Colors.redAccent,

                ),

              ),



              const SizedBox(height: 28),



              // ================================================================

              // TITLE

              // ================================================================



              const Text(

                "Emergency Assistance",

                textAlign: TextAlign.center,



                style: TextStyle(

                  color: Colors.white,

                  fontSize: 28,

                  fontWeight: FontWeight.bold,

                ),

              ),



              const SizedBox(height: 12),



              Text(

                "Use the SOS feature when immediate "

                "assistance is required.",



                textAlign: TextAlign.center,



                style: TextStyle(

                  color: Colors.white

                      .withOpacity(0.65),

                  fontSize: 15,

                  height: 1.5,

                ),

              ),



              const SizedBox(height: 40),



              // ================================================================

              // SOS BUTTON

              // ================================================================



              SizedBox(

                width: double.infinity,

                height: 62,



                child: ElevatedButton.icon(

                  onPressed:

                      _isSendingEmergency

                          ? null

                          : () {

                              _showSOSConfirmation(

                                context,

                              );

                            },



                  icon: _isSendingEmergency

                      ? const SizedBox(

                          width: 24,

                          height: 24,



                          child:

                              CircularProgressIndicator(

                            strokeWidth: 2,

                            color: Colors.white,

                          ),

                        )

                      : const Icon(

                          Icons.warning_rounded,

                          size: 26,

                        ),



                  label: Text(

                    _isSendingEmergency

                        ? "PREPARING SOS..."

                        : "ACTIVATE SOS",



                    style: const TextStyle(

                      fontSize: 17,

                      fontWeight:

                          FontWeight.bold,

                    ),

                  ),



                  style:

                      ElevatedButton.styleFrom(

                    backgroundColor:

                        Colors.redAccent,

                    foregroundColor:

                        Colors.white,

                    elevation: 6,



                    shape:

                        RoundedRectangleBorder(

                      borderRadius:

                          BorderRadius.circular(16),

                    ),

                  ),

                ),

              ),



              const SizedBox(height: 30),



              // ================================================================

              // CURRENT LOCATION CARD

              // ================================================================



              Container(

                width: double.infinity,

                padding:

                    const EdgeInsets.all(20),



                decoration: BoxDecoration(

                  color:

                      const Color(0xFF1B2A41),

                  borderRadius:

                      BorderRadius.circular(18),



                  border: Border.all(

                    color: Colors.redAccent

                        .withOpacity(0.15),

                  ),

                ),



                child: Column(

                  crossAxisAlignment:

                      CrossAxisAlignment.start,



                  children: [

                    const Row(

                      children: [

                        Icon(

                          Icons.location_on_outlined,

                          color:

                              Color(0xFF00C2FF),

                        ),



                        SizedBox(width: 10),



                        Text(

                          "Current Location",

                          style: TextStyle(

                            color: Colors.white,

                            fontSize: 17,

                            fontWeight:

                                FontWeight.bold,

                          ),

                        ),

                      ],

                    ),



                    const SizedBox(height: 18),



                    Container(

                      width: double.infinity,

                      padding:

                          const EdgeInsets.all(14),



                      decoration:

                          BoxDecoration(

                        color:

                            const Color(0xFF111E31),

                        borderRadius:

                            BorderRadius.circular(

                          12,

                        ),

                      ),



                      child: Row(

                        crossAxisAlignment:

                            CrossAxisAlignment

                                .start,



                        children: [

                          Icon(

                            _currentPosition !=

                                    null

                                ? Icons.gps_fixed

                                : Icons.gps_off,



                            color:

                                _currentPosition !=

                                        null

                                    ? Colors

                                        .greenAccent

                                    : Colors

                                        .orangeAccent,



                            size: 22,

                          ),



                          const SizedBox(width: 12),



                          Expanded(

                            child: Column(

                              crossAxisAlignment:

                                  CrossAxisAlignment

                                      .start,



                              children: [

                                Text(

                                  _isGettingLocation

                                      ? "Getting GPS location..."

                                      : _currentPosition !=

                                              null

                                          ? "GPS Location Available"

                                          : "GPS Location Unavailable",



                                  style:

                                      const TextStyle(

                                    color:

                                        Colors.white,

                                    fontSize: 14,

                                    fontWeight:

                                        FontWeight

                                            .w600,

                                  ),

                                ),



                                const SizedBox(

                                  height: 8,

                                ),



                                if (_isGettingLocation)

                                  const LinearProgressIndicator(),



                                if (!_isGettingLocation &&

                                    _currentPosition !=

                                        null)

                                  Text(

                                    _getLocationText(),

                                    style: TextStyle(

                                      color: Colors

                                          .white

                                          .withOpacity(

                                        0.65,

                                      ),

                                      fontSize: 13,

                                      height: 1.5,

                                    ),

                                  ),



                                if (!_isGettingLocation &&

                                    _locationError !=

                                        null)

                                  Text(

                                    _locationError!,

                                    style:

                                        const TextStyle(

                                      color: Colors

                                          .orangeAccent,

                                      fontSize: 13,

                                      height: 1.5,

                                    ),

                                  ),

                              ],

                            ),

                          ),



                          IconButton(

                            tooltip:

                                "Refresh location",



                            onPressed:

                                _isGettingLocation

                                    ? null

                                    : _loadCurrentLocation,



                            icon: const Icon(

                              Icons.refresh,

                              color:

                                  Color(0xFF00C2FF),

                            ),

                          ),

                        ],

                      ),

                    ),



                    const SizedBox(height: 18),



                    const _InfoItem(

                      icon:

                          Icons.location_on_outlined,

                      text:

                          "The driver's current GPS location can be included in the emergency alert.",

                    ),



                    const SizedBox(height: 12),



                    const _InfoItem(

                      icon: Icons.map_outlined,

                      text:

                          "The emergency message contains a map link for the current location.",

                    ),



                    const SizedBox(height: 12),



                    const _InfoItem(

                      icon: Icons.gps_fixed,

                      text:

                          "GPS accuracy is displayed before sending the emergency alert.",

                    ),

                  ],

                ),

              ),



              const SizedBox(height: 20),



              // ================================================================

              // EMERGENCY CONTACT CARD

              // ================================================================



              Container(

                width: double.infinity,

                padding:

                    const EdgeInsets.all(20),



                decoration: BoxDecoration(

                  color:

                      const Color(0xFF1B2A41),

                  borderRadius:

                      BorderRadius.circular(18),



                  border: Border.all(

                    color: Colors.redAccent

                        .withOpacity(0.15),

                  ),

                ),



                child: Column(

                  crossAxisAlignment:

                      CrossAxisAlignment.start,



                  children: [

                    const Row(

                      children: [

                        Icon(

                          Icons.contact_mail_outlined,

                          color:

                              Color(0xFF00C2FF),

                        ),



                        SizedBox(width: 10),



                        Text(

                          "Emergency Contact",

                          style: TextStyle(

                            color: Colors.white,

                            fontSize: 17,

                            fontWeight:

                                FontWeight.bold,

                          ),

                        ),

                      ],

                    ),



                    const SizedBox(height: 18),



                    if (_isLoadingContact)

                      const Padding(

                        padding:

                            EdgeInsets.symmetric(

                          vertical: 20,

                        ),

                        child:

                            Center(

                          child:

                              CircularProgressIndicator(),

                        ),

                      ),



                    if (!_isLoadingContact &&

                        _contactError != null)

                      Container(

                        width: double.infinity,

                        padding:

                            const EdgeInsets.all(14),



                        decoration:

                            BoxDecoration(

                          color:

                              const Color(0xFF111E31),

                          borderRadius:

                              BorderRadius.circular(

                            12,

                          ),

                        ),



                        child: Text(

                          _contactError!,

                          style:

                              const TextStyle(

                            color:

                                Colors.orangeAccent,

                            fontSize: 13,

                            height: 1.5,

                          ),

                        ),

                      ),



                    if (!_isLoadingContact &&

                        _contactError == null)

                      Container(

                        width: double.infinity,

                        padding:

                            const EdgeInsets.all(14),



                        decoration:

                            BoxDecoration(

                          color:

                              const Color(0xFF111E31),

                          borderRadius:

                              BorderRadius.circular(

                            12,

                          ),

                        ),



                        child: Column(

                          children: [

                            _ContactRow(

                              icon:

                                  Icons.person_outline,

                              label: "Name",

                              value:

                                  _emergencyContactName

                                      .isNotEmpty

                                  ? _emergencyContactName

                                  : "Not available",

                            ),



                            const SizedBox(

                              height: 14,

                            ),



                            _ContactRow(

                              icon:

                                  Icons.phone_outlined,

                              label: "Phone",

                              value:

                                  _emergencyContactPhone

                                      .isNotEmpty

                                  ? _emergencyContactPhone

                                  : "Not available",

                            ),



                            const SizedBox(

                              height: 14,

                            ),



                            _ContactRow(

                              icon:

                                  Icons.email_outlined,

                              label: "Email",

                              value:

                                  _emergencyContactEmail

                                      .isNotEmpty

                                  ? _emergencyContactEmail

                                  : "Not available",

                            ),



                            const SizedBox(

                              height: 14,

                            ),



                            _ContactRow(

                              icon:

                                  Icons.people_outline,

                              label:

                                  "Relationship",

                              value:

                                  _emergencyContactRelationship

                                      .isNotEmpty

                                  ? _emergencyContactRelationship

                                  : "Not available",

                            ),

                          ],

                        ),

                      ),



                    const SizedBox(height: 18),



                    const _InfoItem(

                      icon: Icons.person_outline,

                      text:

                          "Emergency contact information is loaded from the backend using the driver's account ID.",

                    ),



                    const SizedBox(height: 12),



                    const _InfoItem(

                      icon: Icons.email_outlined,

                      text:

                          "The emergency email is sent to the email address stored for this emergency contact.",

                    ),



                    const SizedBox(height: 12),



                    const _InfoItem(

                      icon: Icons.link_rounded,

                      text:

                          "The emergency email contains the driver's current map location.",

                    ),

                  ],

                ),

              ),



              const SizedBox(height: 20),



              // ================================================================

              // EMAIL ACTION BUTTON

              // ================================================================



              SizedBox(

                width: double.infinity,

                height: 54,



                child:

                    OutlinedButton.icon(

                  onPressed:

                      _isSendingEmergency ||

                              _emergencyContactEmail

                                  .trim()

                                  .isEmpty

                          ? null

                          : () {

                              _sendEmergencyEmail(

                                context,

                              );

                            },



                  icon: const Icon(

                    Icons.email_rounded,

                  ),



                  label: const Text(

                    "SEND EMERGENCY EMAIL",



                    style: TextStyle(

                      fontWeight:

                          FontWeight.bold,

                    ),

                  ),



                  style:

                      OutlinedButton.styleFrom(

                    foregroundColor:

                        const Color(0xFF00C2FF),



                    side:

                        const BorderSide(

                      color:

                          Color(0xFF00C2FF),

                    ),



                    shape:

                        RoundedRectangleBorder(

                      borderRadius:

                          BorderRadius.circular(

                        14,

                      ),

                    ),

                  ),

                ),

              ),



              const SizedBox(height: 30),

            ],

          ),

        ),

      ),

    );

  }

}



// ==============================================================================

// CONTACT ROW

// ==============================================================================



class _ContactRow extends StatelessWidget {

  final IconData icon;

  final String label;

  final String value;



  const _ContactRow({

    required this.icon,

    required this.label,

    required this.value,

  });



  @override

  Widget build(BuildContext context) {

    return Row(

      crossAxisAlignment:

          CrossAxisAlignment.start,



      children: [

        Icon(

          icon,

          color: const Color(0xFF00C2FF),

          size: 22,

        ),



        const SizedBox(width: 12),



        Expanded(

          child: Column(

            crossAxisAlignment:

                CrossAxisAlignment.start,



            children: [

              Text(

                label,

                style: const TextStyle(

                  color: Colors.white60,

                  fontSize: 12,

                ),

              ),



              const SizedBox(height: 4),



              Text(

                value,

                style: const TextStyle(

                  color: Colors.white,

                  fontSize: 14,

                  fontWeight:

                      FontWeight.w600,

                ),

              ),

            ],

          ),

        ),

      ],

    );

  }

}



// ==============================================================================

// INFORMATION ITEM

// ==============================================================================



class _InfoItem extends StatelessWidget {

  final IconData icon;

  final String text;



  const _InfoItem({

    required this.icon,

    required this.text,

  });



  @override

  Widget build(BuildContext context) {

    return Row(

      crossAxisAlignment:

          CrossAxisAlignment.start,



      children: [

        Icon(

          icon,

          size: 21,

          color: const Color(0xFF00C2FF),

        ),



        const SizedBox(width: 12),



        Expanded(

          child: Text(

            text,

            style: TextStyle(

              color:

                  Colors.white.withOpacity(0.68),

              fontSize: 14,

              height: 1.4,

            ),

          ),

        ),

      ],

    );

  }

}