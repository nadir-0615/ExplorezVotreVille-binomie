import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'api_service.dart'; // Contient VilleData et fetchVilleData

class PagePrincipale extends StatefulWidget {
  const PagePrincipale({super.key});

  @override
  State<PagePrincipale> createState() => _PagePrincipaleState();
}

class _PagePrincipaleState extends State<PagePrincipale> {
  final TextEditingController _villeController = TextEditingController();

  String villeSelectionnee = "Paris";
  VilleData? villeData;
  bool isLoading = false;
  String? error;

  bool villeFavorite = false;
  List<String> villesFavorites = [];
  List<Map<String, String>> lieux = [];

  String? villePrincipale; // 🆕 nouvelle variable : ville favorite principale

  @override
  void initState() {
    super.initState();
    _initialiserVille();
  }

  /// ------------------ Initialisation ------------------
  Future<void> _initialiserVille() async {
    await _loadFavorites();

    // 🆕 Vérifie si une ville principale est enregistrée
    final prefs = await SharedPreferences.getInstance();
    villePrincipale = prefs.getString('ville_principale');

    if (villePrincipale != null) {
      villeSelectionnee = villePrincipale!;
      await _fetchVille(villeSelectionnee);
      await _loadLieux(villeSelectionnee);
      return;
    }

    // Sinon on tente la géolocalisation
    try {
      String? currentCity = await _getCurrentCity();
      if (currentCity != null) {
        villeSelectionnee = currentCity;
      }
    } catch (e) {
      debugPrint("Erreur géolocalisation: $e");
    }

    await _fetchVille(villeSelectionnee);
    await _loadLieux(villeSelectionnee);
  }

  /// ------------------ Géolocalisation ------------------
  Future<String?> _getCurrentCity() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    if (placemarks.isNotEmpty) {
      return placemarks.first.locality ?? "Paris";
    }
    return null;
  }

  /// ------------------ Gestion API ------------------
  Future<void> _fetchVille(String ville) async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final data = await fetchVilleData(ville);
      setState(() {
        villeSelectionnee = data.nom;
        villeData = data;
      });
      _checkFavorite();
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// ------------------ Gestion lieux ------------------
  Future<void> _loadLieux(String ville) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('lieux_$ville') ?? [];
    setState(() {
      lieux = saved
          .map((e) => Map<String, String>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveLieux(String ville) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = lieux.map((e) => json.encode(e)).toList();
    await prefs.setStringList('lieux_$ville', saved);
  }

  void _ajouterLieu() {
    final titreController = TextEditingController();
    final categorieController = TextEditingController();
    final imageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un nouveau lieu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titreController,
              decoration: const InputDecoration(labelText: 'Titre'),
            ),
            TextField(
              controller: categorieController,
              decoration: const InputDecoration(labelText: 'Catégorie'),
            ),
            TextField(
              controller: imageController,
              decoration: const InputDecoration(labelText: 'Image URL'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final newLieu = {
                'titre': titreController.text,
                'categorie': categorieController.text,
                'image': imageController.text,
              };
              setState(() {
                lieux.add(newLieu);
              });
              _saveLieux(villeSelectionnee);
              Navigator.pop(context);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Widget _buildLieuCard(Map<String, String> lieu) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            lieu['image']!,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 60,
              height: 60,
              color: Colors.grey[300],
              child: const Icon(Icons.image_not_supported),
            ),
          ),
        ),
        title: Text(lieu['titre']!),
        subtitle: Text(lieu['categorie']!),
      ),
    );
  }

  /// ------------------ Gestion favoris ------------------
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList('villes_favorites') ?? [];
    setState(() {
      villesFavorites = favs;
    });
    _checkFavorite();
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    if (villeFavorite) {
      villesFavorites.remove(villeSelectionnee);
    } else {
      if (!villesFavorites.contains(villeSelectionnee)) {
        villesFavorites.add(villeSelectionnee);
      }
    }
    await prefs.setStringList('villes_favorites', villesFavorites);
    _checkFavorite();
  }

  void _checkFavorite() {
    setState(() {
      villeFavorite = villesFavorites.contains(villeSelectionnee);
    });
  }

  /// 🆕 Définir une ville favorite comme "principale"
  Future<void> _setVillePrincipale(String ville) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ville_principale', ville);
    setState(() {
      villePrincipale = ville;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$ville est maintenant la ville principale 🌆')),
    );
  }

  /// ------------------ Recherche ------------------
  void _onSearch() async {
    final query = _villeController.text.trim();
    if (query.isEmpty) return;

    List<String> villesTrouvees = [];
    if (query.toLowerCase() == 'par') {
      villesTrouvees = ['Paris, France', 'Parma, Italie'];
    } else {
      villesTrouvees = [query];
    }

    if (villesTrouvees.length == 1) {
      _selectionnerVille(villesTrouvees[0]);
    } else {
      final villeChoisie = await showDialog<String>(
        context: context,
        builder: (_) => SimpleDialog(
          title: const Text('Choisir une ville'),
          children: villesTrouvees
              .map(
                (v) => SimpleDialogOption(
                  child: Text(v),
                  onPressed: () => Navigator.pop(context, v),
                ),
              )
              .toList(),
        ),
      );
      if (villeChoisie != null) {
        _selectionnerVille(villeChoisie);
      }
    }
  }

  void _selectionnerVille(String ville) {
    _fetchVille(ville);
    _loadLieux(ville);
    _villeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorez Votre Ville'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Recherche
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _villeController,
                    decoration: const InputDecoration(
                      labelText: 'Rechercher une ville',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _onSearch(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _onSearch,
                ),
              ],
            ),
            const SizedBox(height: 20),

            /// Affichage météo
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (error != null)
              Text('Erreur: $error', style: const TextStyle(color: Colors.red))
            else if (villeData != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        villeData!.nom,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          villeFavorite ? Icons.star : Icons.star_border,
                          color: Colors.yellow[700],
                        ),
                        onPressed: _toggleFavorite,
                      ),
                      if (villePrincipale == villeData!.nom)
                        const Icon(
                          Icons.home,
                          color: Colors.orange,
                        ), // 🆕 icône ville principale
                    ],
                  ),
                  Text(
                    '☀️ ${villeData!.meteo}, ${villeData!.tempActuelle}°C '
                    '(Min: ${villeData!.tempMin}°C, Max: ${villeData!.tempMax}°C)',
                  ),
                ],
              ),

            const SizedBox(height: 20),
            const Text(
              'Villes favorites :',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            /// 🆕 Liste des villes favorites avec option "définir principale"
            Wrap(
              spacing: 8,
              children: villesFavorites.map((v) {
                final isMain = v == villePrincipale;
                return ActionChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(v),
                      if (isMain)
                        const Icon(Icons.home, size: 18, color: Colors.orange),
                    ],
                  ),
                  onPressed: () {
                    _selectionnerVille(v);
                    _setVillePrincipale(v);
                  }, // 🆕 clic long = définir principale
                );
              }).toList(),
            ),

            const SizedBox(height: 20),
            const Text(
              'Lieux enregistrés :',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ...lieux.map(_buildLieuCard),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        onPressed: _ajouterLieu,
        child: const Icon(Icons.add),
      ),
    );
  }
}
