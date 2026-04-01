import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationController extends ChangeNotifier {
  static const String _locationLabelKey = 'device_location_label';

  String _locationLabel = '';
  bool _loading = false;

  String get locationLabel => _locationLabel;
  bool get isLoading => _loading;

  LocationController() {
    _load();
    // Automatically refresh location on initialization
    refreshFromDevice();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _locationLabel = prefs.getString(_locationLabelKey) ?? '';
    // If no cached location, set a default message
    if (_locationLabel.isEmpty) {
      _locationLabel = 'Detecting location...';
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_locationLabelKey, _locationLabel);
  }

  Future<void> refreshFromDevice() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _locationLabel = 'Location services disabled';
        await _save();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _locationLabel = 'Location permission denied';
        await _save();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 8),
      );

      // Convert coordinates to readable address
      try {
        final List<Placemark> placemarks = await placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        
        if (placemarks.isNotEmpty) {
          final Placemark place = placemarks[0];
          String address = '';
          
          // Build address from available components
          if (place.street?.isNotEmpty == true) {
            address += place.street!;
          }
          if (place.locality?.isNotEmpty == true) {
            address += address.isNotEmpty ? ', ${place.locality}' : place.locality!;
          }
          if (place.administrativeArea?.isNotEmpty == true) {
            address += address.isNotEmpty ? ', ${place.administrativeArea}' : place.administrativeArea!;
          }
          if (place.country?.isNotEmpty == true) {
            address += address.isNotEmpty ? ', ${place.country}' : place.country!;
          }
          
          _locationLabel = address.isNotEmpty ? address : 'Current location';
        } else {
          // Fallback to nominatim for web or if native geocoding is empty
          _locationLabel = await _getNominatimAddress(pos.latitude, pos.longitude);
        }
      } catch (e) {
        print('Native Geocoding error: $e');
        // Fallback to nominatim for web
        _locationLabel = await _getNominatimAddress(pos.latitude, pos.longitude);
      }
      await _save();
    } catch (e) {
      print('Location error: $e');
      _locationLabel = 'Location access denied';
      await _save();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String> _getNominatimAddress(double lat, double lng) async {
    try {
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1'),
        headers: kIsWeb ? {} : {'User-Agent': 'FSHub_App'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['display_name'] as String?;
        if (address != null) {
          // Clean up the address a bit for display
          final parts = address.split(',');
          if (parts.length > 3) {
            return parts.take(3).join(',').trim();
          }
          return address;
        }
      }
      return '$lat, $lng'; // Last fallback
    } catch (e) {
      print('Nominatim error: $e');
      return '$lat, $lng';
    }
  }
}
