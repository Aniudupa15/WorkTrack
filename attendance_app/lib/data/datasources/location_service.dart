import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Turn on location on your phone, then try again.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Allow location access to punch in.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        kIsWeb
            ? 'Location is blocked for this site. Allow it in your browser’s '
                  'site settings, then try again.'
            : 'Location is blocked for PunchIn. Allow it in Settings, then '
                  'try again.',
      );
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  bool isWithinRadius(LatLng current, LatLng target, double radiusInMeters) {
    double distance = calculateDistance(
      current.latitude,
      current.longitude,
      target.latitude,
      target.longitude,
    );
    return distance <= radiusInMeters;
  }
}
