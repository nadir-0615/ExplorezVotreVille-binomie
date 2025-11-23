import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// =========================================================
/// GEOLOCATION SERVICE - GPS ultra propre
/// =========================================================
class GeolocationService {
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  static Future<LocationPermission> checkAndRequestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  static Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await checkAndRequestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('❌ Erreur géolocalisation: $e');
      return null;
    }
  }

  static Future<String?> getCityNameFromPosition(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        return placemark.locality ??
            placemark.subLocality ??
            placemark.administrativeArea;
      }
    } catch (e) {
      print('❌ Erreur conversion GPS -> ville: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getCurrentLocationData() async {
    final position = await getCurrentPosition();
    if (position == null) return null;

    final cityName = await getCityNameFromPosition(position);
    return {
      'city': cityName ?? 'Ville inconnue',
      'latitude': position.latitude,
      'longitude': position.longitude,
    };
  }
}
