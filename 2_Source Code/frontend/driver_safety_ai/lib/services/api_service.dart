import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // ============================================================
  // BACKEND URL
  // ============================================================

  // Chrome + FastAPI on the same PC
  static const String baseUrl = "http://192.168.31.55:8000";
  // ============================================================
  // DRIVER SAFETY AI - DETECTION API
  // ============================================================

  static Future<Map<String, dynamic>> detect(
    dynamic image,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/detect'),
      );

      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            image as Uint8List,
            filename: 'capture.jpg',
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            image.path,
          ),
        );
      }

      final response = await request.send();
      final body = await response.stream.bytesToString();

      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {
        'success': false,
        'message': 'Invalid response from detection API.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Unable to connect to detection server.',
        'error': e.toString(),
      };
    }
  }

  // ============================================================
  // SEND OTP
  // ============================================================

  static Future<Map<String, dynamic>> sendOtp({
    required String identifier,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-otp'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'identifier': identifier,
        }),
      );

      final Map<String, dynamic> data =
          jsonDecode(response.body);

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        return {
          'success': true,
          ...data,
        };
      }

      return {
        'success': false,
        ...data,
        'message':
            data['message'] ??
            'Failed to send OTP.',
      };
    } catch (e) {
      return {
        'success': false,
        'message':
            'Unable to connect to the server.',
        'error': e.toString(),
      };
    }
  }

  // ============================================================
  // VERIFY OTP
  // ============================================================

  static Future<Map<String, dynamic>> verifyOtp({
    required String identifier,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'identifier': identifier,
          'otp': otp,
        }),
      );

      final Map<String, dynamic> data =
          jsonDecode(response.body);

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        return {
          'success': true,
          ...data,
        };
      }

      return {
        'success': false,
        ...data,
        'message':
            data['message'] ??
            'Invalid OTP.',
      };
    } catch (e) {
      return {
        'success': false,
        'message':
            'Unable to connect to the server.',
        'error': e.toString(),
      };
    }
  }

  // ============================================================
  // GET EMERGENCY CONTACT
  // ============================================================
  //
  // Flutter
  //    ↓
  // GET /emergency-contact?account_id=...
  //    ↓
  // FastAPI
  //    ↓
  // driver_profiles
  //
  // Returns:
  // name
  // phone
  // email
  // relationship
  //
  // Existing functionality is preserved.
  // ============================================================

  static Future<Map<String, dynamic>> getEmergencyContact({
    required String accountId,
  }) async {
    try {
      final trimmedAccountId =
          accountId.trim();

      if (trimmedAccountId.isEmpty) {
        return {
          'success': false,
          'message':
              'Account ID is not available.',
        };
      }

      final uri = Uri.parse(
        '$baseUrl/emergency-contact',
      ).replace(
        queryParameters: {
          'account_id': trimmedAccountId,
        },
      );

      debugPrint(
        'GET EMERGENCY CONTACT',
      );

      debugPrint(
        'Account ID: $trimmedAccountId',
      );

      debugPrint(
        'URL: $uri',
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
        },
      );

      debugPrint(
        'Emergency contact status: '
        '${response.statusCode}',
      );

      debugPrint(
        'Emergency contact response: '
        '${response.body}',
      );

      Map<String, dynamic> data;

      try {
        final decoded =
            jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          data = decoded;
        } else {
          return {
            'success': false,
            'message':
                'Invalid response from emergency contact API.',
          };
        }
      } catch (e) {
        return {
          'success': false,
          'message':
              'Invalid JSON response from server.',
          'error': e.toString(),
        };
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        return {
          'success': true,
          ...data,
        };
      }

      return {
        'success': false,
        ...data,
        'message':
            data['message'] ??
            'Unable to load emergency contact.',
      };
    } catch (e) {
      debugPrint(
        'GET EMERGENCY CONTACT ERROR: $e',
      );

      return {
        'success': false,
        'message':
            'Unable to connect to the server.',
        'error': e.toString(),
      };
    }
  }

  // ============================================================
  // SAVE / UPDATE EMERGENCY CONTACT
  // ============================================================
  //
  // This uses the backend's existing:
  //
  // POST /emergency-contact
  //
  // The backend currently accepts the complete DriverProfileRequest,
  // so vehicle fields are also included.
  //
  // We are NOT changing the backend structure here.
  // ============================================================

  static Future<Map<String, dynamic>>
      saveEmergencyContact({
    required String accountId,
    String vehicleNumber = '',
    String vehicleType = '',
    String vehicleModel = '',
    String vehicleOtherInfo = '',
    String emergencyContactName = '',
    String emergencyContactPhone = '',
    String emergencyContactEmail = '',
    String emergencyContactRelationship = '',
  }) async {
    try {
      final trimmedAccountId =
          accountId.trim();

      if (trimmedAccountId.isEmpty) {
        return {
          'success': false,
          'message':
              'Account ID is not available.',
        };
      }

      final response = await http.post(
        Uri.parse(
          '$baseUrl/emergency-contact',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'account_id': trimmedAccountId,

          'vehicle_number':
              vehicleNumber.trim(),

          'vehicle_type':
              vehicleType.trim(),

          'vehicle_model':
              vehicleModel.trim(),

          'vehicle_other_info':
              vehicleOtherInfo.trim(),

          'emergency_contact_name':
              emergencyContactName.trim(),

          'emergency_contact_phone':
              emergencyContactPhone.trim(),

          'emergency_contact_email':
              emergencyContactEmail.trim(),

          'emergency_contact_relationship':
              emergencyContactRelationship.trim(),
        }),
      );

      debugPrint(
        'SAVE EMERGENCY CONTACT STATUS: '
        '${response.statusCode}',
      );

      debugPrint(
        'SAVE EMERGENCY CONTACT RESPONSE: '
        '${response.body}',
      );

      final decoded =
          jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        if (response.statusCode >= 200 &&
            response.statusCode < 300) {
          return {
            'success': true,
            ...decoded,
          };
        }

        return {
          'success': false,
          ...decoded,
          'message':
              decoded['message'] ??
              'Unable to save emergency contact.',
        };
      }

      return {
        'success': false,
        'message':
            'Invalid response from server.',
      };
    } catch (e) {
      debugPrint(
        'SAVE EMERGENCY CONTACT ERROR: $e',
      );

      return {
        'success': false,
        'message':
            'Unable to connect to the server.',
        'error': e.toString(),
      };
    }
  }

  // ============================================================
  // SEND EMERGENCY ALERT EMAIL
  // ============================================================
  //
  // Flutter
  //    ↓
  // POST /emergency-alert/email
  //    ↓
  // FastAPI
  //    ↓
  // Saved emergency contact email
  //    ↓
  // Email
  //
  // Existing functionality is preserved.
  // ============================================================

  static Future<Map<String, dynamic>> sendEmergencyAlert({
    required String accountId,
    required String status,
    String timestamp = '',
    String latitude = '',
    String longitude = '',
    String accuracy = '',
    String googleMapsLink = '',
    String alertMessage = '',
  }) async {
    try {
      final trimmedAccountId =
          accountId.trim();

      if (trimmedAccountId.isEmpty) {
        return {
          'success': false,
          'message':
              'Account ID is not available.',
        };
      }

      final response = await http.post(
        Uri.parse(
          '$baseUrl/emergency-alert/email',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'account_id':
              trimmedAccountId,

          'status':
              status.trim(),

          'timestamp':
              timestamp.trim(),

          'latitude':
              latitude.trim(),

          'longitude':
              longitude.trim(),

          'accuracy':
              accuracy.trim(),

          'google_maps_link':
              googleMapsLink.trim(),

          'alert_message':
              alertMessage.trim(),
        }),
      );

      debugPrint(
        'EMERGENCY ALERT EMAIL STATUS: '
        '${response.statusCode}',
      );

      debugPrint(
        'EMERGENCY ALERT EMAIL RESPONSE: '
        '${response.body}',
      );

      final decoded =
          jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        if (response.statusCode >= 200 &&
            response.statusCode < 300) {
          return {
            'success': true,
            ...decoded,
          };
        }

        return {
          'success': false,
          ...decoded,
          'message':
              decoded['message'] ??
              'Unable to send emergency alert email.',
        };
      }

      return {
        'success': false,
        'message':
            'Invalid response from emergency email API.',
      };
    } catch (e) {
      debugPrint(
        'EMERGENCY ALERT EMAIL ERROR: $e',
      );

      return {
        'success': false,
        'message':
            'Unable to connect to the emergency email server.',
        'error': e.toString(),
      };
    }
  }
}