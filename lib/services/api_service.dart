import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ville.dart';

/// =========================================================
/// API SERVICE - Météo + Géocodage COMPLET
/// =========================================================
class ApiService {
  // ⚠️ REMPLACE PAR TA VRAIE CLÉ API OpenWeatherMap
  // Inscris-toi gratuitement sur : https://openweathermap.org/api
  static const weatherApiKey = "10b8438c4f211d68df5e73447919a0b0";

  /// Recherche multi-villes (pour homonymes : Paris France vs Paris Texas)
  static Future<List<Map<String, dynamic>>> searchCities(String query) async {
    try {
      final geoResponse = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=10',
        ),
        headers: {'User-Agent': 'ExplorezVotreVille'},
      );

      if (geoResponse.statusCode != 200) {
        throw Exception('Erreur recherche');
      }

      final geoData = json.decode(geoResponse.body) as List;

      if (geoData.isEmpty) {
        throw Exception('Aucune ville trouvée');
      }

      return geoData.map<Map<String, dynamic>>((city) {
        return {
          'name': city['display_name'] ?? 'Nom inconnu',
          'lat': double.parse(city['lat']),
          'lon': double.parse(city['lon']),
          'type': city['type'] ?? '',
        };
      }).toList();
    } catch (e) {
      throw Exception('Erreur recherche: $e');
    }
  }

  /// Récupérer ville + météo par nom
  static Future<Ville> fetchVilleData(String villeNom) async {
    try {
      final geoResponse = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$villeNom&format=json&limit=1',
        ),
        headers: {'User-Agent': 'ExplorezVotreVille'},
      );

      if (geoResponse.statusCode != 200) {
        throw Exception('Ville introuvable');
      }

      final geoData = json.decode(geoResponse.body);
      if (geoData.isEmpty) throw Exception('Ville introuvable');

      final lat = double.parse(geoData[0]['lat']);
      final lon = double.parse(geoData[0]['lon']);

      final weatherResponse = await http.get(
        Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$weatherApiKey&units=metric&lang=fr',
        ),
      );

      if (weatherResponse.statusCode != 200) {
        throw Exception('Erreur météo');
      }

      final weatherData = json.decode(weatherResponse.body);

      return Ville(
        nom: villeNom,
        latitude: lat,
        longitude: lon,
        meteo: weatherData['weather'][0]['description'],
        tempActuelle: weatherData['main']['temp'].toDouble(),
        tempMin: weatherData['main']['temp_min'].toDouble(),
        tempMax: weatherData['main']['temp_max'].toDouble(),
      );
    } catch (e) {
      throw Exception('Erreur API: $e');
    }
  }

  /// Récupérer ville + météo par coordonnées GPS
  static Future<Ville> fetchVilleDataByCoords({
    required double lat,
    required double lon,
  }) async {
    try {
      final geoResponse = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json',
        ),
        headers: {'User-Agent': 'ExplorezVotreVille'},
      );

      String cityName = 'Ville actuelle';
      if (geoResponse.statusCode == 200) {
        final geoData = json.decode(geoResponse.body);
        cityName = geoData['address']?['city'] ??
            geoData['address']?['town'] ??
            geoData['address']?['village'] ??
            'Ville actuelle';
      }

      final weatherResponse = await http.get(
        Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$weatherApiKey&units=metric&lang=fr',
        ),
      );

      if (weatherResponse.statusCode != 200) {
        throw Exception('Erreur météo');
      }

      final weatherData = json.decode(weatherResponse.body);

      return Ville(
        nom: cityName,
        latitude: lat,
        longitude: lon,
        meteo: weatherData['weather'][0]['description'],
        tempActuelle: weatherData['main']['temp'].toDouble(),
        tempMin: weatherData['main']['temp_min'].toDouble(),
        tempMax: weatherData['main']['temp_max'].toDouble(),
      );
    } catch (e) {
      throw Exception('Erreur API coords: $e');
    }
  }

  /// Reverse geocoding : infos d'un lieu par coordonnées
  static Future<Map<String, dynamic>?> getLieuInfoByCoords({
    required double lat,
    required double lon,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&addressdetails=1',
        ),
        headers: {'User-Agent': 'ExplorezVotreVille'},
      );

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      return {
        'name': data['name'] ?? data['display_name'] ?? 'Lieu sans nom',
        'type': data['type'] ?? '',
        'address': data['display_name'] ?? '',
      };
    } catch (e) {
      print('❌ Erreur reverse geocoding: $e');
      return null;
    }
  }
}
