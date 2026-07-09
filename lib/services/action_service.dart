import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/action.dart';

class ActionService {
  /// Executes a backend-issued action.
  ///
  /// For `open_maps` this just launches the URL and returns null. For
  /// `get_location` it fetches device GPS coordinates and returns a
  /// follow-up message to send back to the backend as the next user turn.
  static Future<String?> execute(Action action) async {
    switch (action.type) {
      case 'open_maps':
        await _openMaps(action.payload);
        return null;
      case 'get_location':
        return _getLocationFollowUp();
      default:
        return null;
    }
  }

  static Future<void> _openMaps(Map<String, dynamic> payload) async {
    final lat = payload['latitude'];
    final lon = payload['longitude'];
    final query = payload['query'] as String?;

    final Uri uri;
    if (lat != null && lon != null) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    } else {
      uri = Uri.parse(
        'https://www.google.com/maps/search/${Uri.encodeComponent(query ?? '')}',
      );
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<String> _getLocationFollowUp() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return "I couldn't get a location fix, boss — permission denied.";
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return "Location services are off, boss — can't get a fix.";
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );
    return 'My current location is lat: ${position.latitude}, '
        'lon: ${position.longitude}';
  }
}
