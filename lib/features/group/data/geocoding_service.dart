import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingResult {
  final double lat;
  final double lng;
  final String displayName;

  const GeocodingResult({
    required this.lat,
    required this.lng,
    required this.displayName,
  });
}

class GeocodingService {
  static const _baseUrl = 'https://searchlocation-izuumdquha-du.a.run.app';

  static Future<List<GeocodingResult>> searchLocations(String query) async {
    final uri = Uri.parse('$_baseUrl?query=${Uri.encodeComponent(query)}');

    final response = await http.get(uri);

    if (response.statusCode != 200) return [];

    final data = json.decode(response.body);
    final List<dynamic> documents = data['documents'] ?? [];
    return documents.map((d) {
      return GeocodingResult(
        lat: double.parse(d['y']),
        lng: double.parse(d['x']),
        displayName: d['place_name'] ?? query,
      );
    }).toList();
  }
}
