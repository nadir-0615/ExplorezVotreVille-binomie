import 'package:flutter/material.dart';
import '../models/ville.dart';

/// =========================================================
/// WEATHER BANNER - Bandeau météo dynamique et stylé
/// =========================================================
class WeatherBanner extends StatelessWidget {
  final Ville? villeData;
  final bool isLoading;

  const WeatherBanner({
    Key? key,
    this.villeData,
    this.isLoading = false,
  }) : super(key: key);

  IconData _getWeatherIcon(String meteo) {
    final m = meteo.toLowerCase();
    if (m.contains('clear') ||
        m.contains('ensoleillé') ||
        m.contains('dégagé')) {
      return Icons.wb_sunny;
    } else if (m.contains('cloud') || m.contains('nuage')) {
      return Icons.wb_cloudy;
    } else if (m.contains('rain') || m.contains('pluie')) {
      return Icons.umbrella;
    } else if (m.contains('snow') || m.contains('neige')) {
      return Icons.ac_unit;
    } else if (m.contains('storm') || m.contains('orage')) {
      return Icons.flash_on;
    } else if (m.contains('fog') || m.contains('brouillard')) {
      return Icons.cloud;
    }
    return Icons.wb_sunny;
  }

  Color _getWeatherIconColor(String meteo) {
    final m = meteo.toLowerCase();
    if (m.contains('clear') || m.contains('ensoleillé')) return Colors.amber;
    if (m.contains('rain') || m.contains('pluie')) return Colors.blueAccent;
    if (m.contains('snow') || m.contains('neige'))
      return Colors.lightBlueAccent;
    if (m.contains('storm') || m.contains('orage')) return Colors.deepPurple;
    return Colors.white70;
  }

  List<Color> _getGradientColors(String? meteo) {
    if (meteo == null) {
      return [const Color(0xFF1E3C72), const Color(0xFF2A5298)];
    }

    final m = meteo.toLowerCase();
    if (m.contains('clear') || m.contains('ensoleillé')) {
      return [const Color(0xFF56CCF2), const Color(0xFFF2994A)];
    } else if (m.contains('rain') || m.contains('pluie')) {
      return [const Color(0xFF373B44), const Color(0xFF4286f4)];
    } else if (m.contains('cloud') || m.contains('nuage')) {
      return [const Color(0xFFBDC3C7), const Color(0xFF2C3E50)];
    } else if (m.contains('snow') || m.contains('neige')) {
      return [const Color(0xFFE0EAFC), const Color(0xFFCFDEF3)];
    } else if (m.contains('storm') || m.contains('orage')) {
      return [const Color(0xFF232526), const Color(0xFF414345)];
    }
    return [const Color(0xFF1E3C72), const Color(0xFF2A5298)];
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (villeData == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.location_searching, color: Colors.white70, size: 40),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recherchez une ville',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Météo non disponible',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final gradientColors = _getGradientColors(villeData!.meteo);
    final weatherIcon = _getWeatherIcon(villeData!.meteo);
    final iconColor = _getWeatherIconColor(villeData!.meteo);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1.0),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.elasticOut,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Icon(weatherIcon, color: iconColor, size: 55),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  villeData!.nom,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  villeData!.meteo.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '${villeData!.tempActuelle.toStringAsFixed(1)}°',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.arrow_upward,
                                color: Colors.redAccent, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${villeData!.tempMax.toStringAsFixed(0)}°',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.arrow_downward,
                                color: Colors.lightBlueAccent, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${villeData!.tempMin.toStringAsFixed(0)}°',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
