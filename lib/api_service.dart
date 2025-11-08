import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class VilleData {
  final String nom;
  final double tempActuelle;
  final double tempMin;
  final double tempMax;
  final String meteo;

  VilleData({
    required this.nom,
    required this.tempActuelle,
    required this.tempMin,
    required this.tempMax,
    required this.meteo,
  });
}

Future<VilleData> fetchVilleData(String ville) async {
  final apiKey = 'b5df95a64bbcb10ba89b89a6257dbea6';
  final url =
      'https://api.openweathermap.org/data/2.5/weather?q=$ville&units=metric&lang=fr&appid=$apiKey';

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    return VilleData(
      nom: data['name'],
      tempActuelle: data['main']['temp'].toDouble(),
      tempMin: data['main']['temp_min'].toDouble(),
      tempMax: data['main']['temp_max'].toDouble(),
      meteo: data['weather'][0]['description'],
    );
  } else {
    debugPrint('Erreur HTTP ${response.statusCode}: ${response.body}');
    throw Exception(
      'Impossible de récupérer les données de $ville (code ${response.statusCode})',
    );
  }
}
