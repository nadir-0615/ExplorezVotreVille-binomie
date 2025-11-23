import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../data/database_helper.dart';
import '../models/ville.dart';
import '../services/api_service.dart';
import '../services/geolocation_service.dart';
import '../widgets/weather_banner.dart';
import '../widgets/category_filter.dart';
import '../widgets/lieu_card.dart';

class PagePrincipale extends StatefulWidget {
  const PagePrincipale({super.key});

  @override
  State<PagePrincipale> createState() => _PagePrincipaleState();
}

class _PagePrincipaleState extends State<PagePrincipale>
    with SingleTickerProviderStateMixin {
  // ========== CONTROLEURS ==========
  final TextEditingController _villeController = TextEditingController();
  final MapController _mapController = MapController();
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ========== ÉTATS ==========
  Ville? villeData;
  bool isLoading = false;
  String? error;

  // Position GPS
  double? userLat;
  double? userLon;

  // Position ville sélectionnée
  double? villeLat;
  double? villeLon;

  // Ville actuelle
  int? villeIdActuelle;
  String villeNomActuelle = '';

  // Lieux
  List<Map<String, dynamic>> lieux = [];
  String? categorieSelectionnee;

  // Favoris
  List<Map<String, dynamic>> villesFavorites = [];
  bool villeFavorite = false;

  // Ajout lieu en cours
  bool ajoutLieuEnCours = false;
  String? nomLieuTemp;
  String? categorieLieuTemp;
  List<String>? _imagesUrlsTemp;
  double? _noteTemp;
  String? _commentaireTemp;

  // Animation marqueur (AMÉLIORÉE - plus visible)
  late AnimationController _markerController;
  late Animation<double> _markerAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Animation du marqueur - DOUBLE EFFET (scale + pulse)
    _markerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _markerAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _markerController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.0, end: 20.0).animate(
      CurvedAnimation(parent: _markerController, curve: Curves.easeOut),
    );

    _initialiser();
  }

  @override
  void dispose() {
    _markerController.dispose();
    _villeController.dispose();
    super.dispose();
  }

  // ==================== INITIALISATION ====================

  Future<void> _initialiser() async {
    await _loadFavorites();

    // Vérifier ville principale
    final villePrincipale = await _db.getVillePrincipale();
    if (villePrincipale != null) {
      await _chargerVilleDepuisDB(villePrincipale);
      return;
    }

    // Sinon géolocalisation
    await _geolocalisationInitiale();
  }

  Future<void> _geolocalisationInitiale() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final locationData = await GeolocationService.getCurrentLocationData();

      if (locationData != null) {
        userLat = locationData['latitude'];
        userLon = locationData['longitude'];
        final cityName = locationData['city'];

        // Récupérer météo
        final ville = await ApiService.fetchVilleDataByCoords(
          lat: userLat!,
          lon: userLon!,
        );

        setState(() {
          villeData = ville;
          villeNomActuelle = cityName;
          villeLat = userLat;
          villeLon = userLon;
        });

        // Enregistrer en DB
        await _enregistrerVilleEnDB(ville);

        _centrerCarte();
      } else {
        setState(() {
          error = 'Impossible de récupérer votre position GPS';
        });
      }
    } catch (e) {
      setState(() {
        error = 'Erreur : $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // ==================== RECHERCHE VILLE ====================

  Future<void> _rechercherVille() async {
    final query = _villeController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // Recherche multi-résultats
      final resultats = await ApiService.searchCities(query);

      if (resultats.length == 1) {
        // Une seule ville trouvée
        await _selectionnerVilleParCoords(
          resultats[0]['lat'],
          resultats[0]['lon'],
        );
      } else {
        // Plusieurs villes : afficher dialogue de choix
        _afficherChoixVilles(resultats);
      }
    } catch (e) {
      setState(() {
        error = 'Erreur recherche : $e';
        isLoading = false;
      });
    }
  }

  void _afficherChoixVilles(List<Map<String, dynamic>> villes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisissez une ville'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: villes.length,
            itemBuilder: (context, index) {
              final ville = villes[index];
              return ListTile(
                leading: const Icon(Icons.location_city, color: Colors.teal),
                title: Text(ville['name']),
                subtitle: Text(ville['type']),
                onTap: () {
                  Navigator.pop(context);
                  _selectionnerVilleParCoords(ville['lat'], ville['lon']);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _selectionnerVilleParCoords(double lat, double lon) async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final ville = await ApiService.fetchVilleDataByCoords(lat: lat, lon: lon);

      setState(() {
        villeData = ville;
        villeNomActuelle = ville.nom;
        villeLat = lat;
        villeLon = lon;
      });

      await _enregistrerVilleEnDB(ville);

      print('🏙️ Ville sélectionnée: $villeNomActuelle (ID: $villeIdActuelle)');

      await _loadLieux(); // ← IMPORTANT : Charge les lieux existants
      _centrerCarte();
      _checkFavorite();
    } catch (e) {
      setState(() {
        error = 'Erreur : $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // ==================== BASE DE DONNÉES ====================

  Future<void> _enregistrerVilleEnDB(Ville ville) async {
    final existante = await _db.getVilleByNom(ville.nom);

    if (existante == null) {
      villeIdActuelle = await _db.insertVille(
        nom: ville.nom,
        latitude: ville.latitude,
        longitude: ville.longitude,
      );
    } else {
      villeIdActuelle = existante['id'];
    }
  }

  Future<void> _chargerVilleDepuisDB(Map<String, dynamic> villeDB) async {
    setState(() {
      isLoading = true;
    });

    try {
      final ville = await ApiService.fetchVilleDataByCoords(
        lat: villeDB['latitude'],
        lon: villeDB['longitude'],
      );

      setState(() {
        villeData = ville;
        villeNomActuelle = villeDB['nom'];
        villeLat = villeDB['latitude'];
        villeLon = villeDB['longitude'];
        villeIdActuelle = villeDB['id'];
      });

      print('🏙️ Ville chargée: $villeNomActuelle (ID: $villeIdActuelle)');

      await _loadLieux(); // ← IMPORTANT : Charge les lieux de cette ville
      _centrerCarte();
      _checkFavorite();
    } catch (e) {
      setState(() {
        error = 'Erreur : $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
// ==================== LIEUX ====================

  Future<void> _loadLieux() async {
    if (villeIdActuelle == null) {
      print('⚠️ Aucune ville sélectionnée, impossible de charger les lieux');
      return;
    }

    print('📍 Chargement des lieux pour la ville ID: $villeIdActuelle');

    if (categorieSelectionnee == null) {
      lieux = await _db.getLieuxByVille(villeIdActuelle!);
      print('✅ ${lieux.length} lieux chargés (toutes catégories)');
    } else {
      lieux = await _db.getLieuxByCategorie(
          villeIdActuelle!, categorieSelectionnee!);
      print(
          '✅ ${lieux.length} lieux chargés (catégorie: $categorieSelectionnee)');
    }

    // Affiche les lieux en console
    for (var lieu in lieux) {
      print('  - ${lieu['titre']} (${lieu['categorie']})');
    }

    setState(() {});
  }

  void _demarrerAjoutLieu() {
    showDialog(
      context: context,
      builder: (context) {
        String nom = '';
        String categorie = 'musee';
        List<String> imagesUrls = [];
        TextEditingController imageController = TextEditingController();
        double note = 3.0;
        String commentaire = '';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                '✨ Ajouter un lieu',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Nom du lieu
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Nom du lieu',
                        prefixIcon: Icon(Icons.edit, color: Colors.teal),
                      ),
                      onChanged: (value) => nom = value,
                    ),
                    const SizedBox(height: 16),

                    // Catégorie
                    DropdownButtonFormField<String>(
                      value: categorie,
                      decoration: const InputDecoration(
                        labelText: 'Catégorie',
                        prefixIcon: Icon(Icons.category, color: Colors.teal),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'musee',
                          child: Row(
                            children: [
                              Icon(Icons.museum,
                                  size: 20, color: Colors.purple),
                              SizedBox(width: 8),
                              Text('Musée'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'restaurant',
                          child: Row(
                            children: [
                              Icon(Icons.restaurant,
                                  size: 20, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Restaurant'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'parc',
                          child: Row(
                            children: [
                              Icon(Icons.park, size: 20, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Parc'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'monument',
                          child: Row(
                            children: [
                              Icon(Icons.account_balance,
                                  size: 20, color: Colors.brown),
                              SizedBox(width: 8),
                              Text('Monument'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'stade',
                          child: Row(
                            children: [
                              Icon(Icons.stadium, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Stade'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          categorie = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // ========== AJOUT MULTIPLE D'IMAGES ==========
                    const Divider(),
                    Row(
                      children: [
                        const Icon(Icons.photo_library, color: Colors.teal),
                        const SizedBox(width: 8),
                        Text(
                          'Photos (${imagesUrls.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Liste des images ajoutées
                    if (imagesUrls.isNotEmpty)
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: imagesUrls.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.teal),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      imagesUrls[index],
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stack) {
                                        return const Icon(Icons.broken_image);
                                      },
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        imagesUrls.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Champ pour ajouter une nouvelle image
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: imageController,
                            decoration: const InputDecoration(
                              labelText: 'URL d\'une photo',
                              hintText: 'https://...',
                              prefixIcon: Icon(Icons.link, color: Colors.teal),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle,
                              color: Colors.teal, size: 32),
                          onPressed: () {
                            if (imageController.text.isNotEmpty) {
                              setDialogState(() {
                                imagesUrls.add(imageController.text);
                                imageController.clear();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Note avec étoiles
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Note :',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            return IconButton(
                              icon: Icon(
                                index < note.round()
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 32,
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  note = (index + 1).toDouble();
                                });
                              },
                            );
                          }),
                        ),
                        Center(
                          child: Text(
                            '${note.toStringAsFixed(1)} / 5.0',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Commentaire
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Commentaire (optionnel)',
                        prefixIcon: Icon(Icons.comment, color: Colors.teal),
                        hintText: 'Votre avis sur ce lieu...',
                      ),
                      maxLines: 3,
                      onChanged: (value) => commentaire = value,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    if (nom.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('❌ Entrez un nom pour le lieu'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    setState(() {
                      nomLieuTemp = nom;
                      categorieLieuTemp = categorie;
                      ajoutLieuEnCours = true;
                    });

                    _imagesUrlsTemp = imagesUrls;
                    _noteTemp = note;
                    _commentaireTemp = commentaire.isEmpty ? null : commentaire;

                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('📍 Cliquez sur la carte pour placer le lieu'),
                        duration: Duration(seconds: 3),
                        backgroundColor: Colors.teal,
                      ),
                    );
                  },
                  icon: const Icon(Icons.location_on),
                  label: const Text('Placer sur la carte'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _ajouterLieuSurCarte(LatLng position) async {
    if (villeIdActuelle == null ||
        nomLieuTemp == null ||
        categorieLieuTemp == null) {
      print(
          '❌ Impossible d\'ajouter : villeId=$villeIdActuelle, nom=$nomLieuTemp, cat=$categorieLieuTemp');
      return;
    }

    print(
        '📍 Ajout du lieu: $nomLieuTemp à ${position.latitude}, ${position.longitude}');

    try {
      await _db.insertLieu(
        titre: nomLieuTemp!,
        categorie: categorieLieuTemp!,
        imagesUrls: _imagesUrlsTemp,
        latitude: position.latitude,
        longitude: position.longitude,
        note: _noteTemp,
        commentaire: _commentaireTemp,
        villeId: villeIdActuelle!,
      );

      print('✅ Lieu ajouté en base de données');

      final nomSauvegarde = nomLieuTemp;

      setState(() {
        ajoutLieuEnCours = false;
        nomLieuTemp = null;
        categorieLieuTemp = null;
        _imagesUrlsTemp = null;
        _noteTemp = null;
        _commentaireTemp = null;
      });

      await _loadLieux();

      print('✅ Liste des lieux rechargée : ${lieux.length} lieux');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Lieu "$nomSauvegarde" ajouté avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur lors de l\'ajout du lieu: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _afficherInfoLieu(LatLng position) async {
    final info = await ApiService.getLieuInfoByCoords(
      lat: position.latitude,
      lon: position.longitude,
    );

    if (info == null || !mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              info['name'],
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('Type : ${info['type']}'),
            Text('Adresse : ${info['address']}'),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.close),
              label: const Text('Fermer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _centrerSurLieu(Map<String, dynamic> lieu) {
    _mapController.move(
      LatLng(lieu['latitude'], lieu['longitude']),
      16.0,
    );
  }

  Future<void> _supprimerLieu(int lieuId) async {
    await _db.deleteLieu(lieuId);
    await _loadLieux();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑️ Lieu supprimé')),
      );
    }
  }

  // ==================== FAVORIS ====================

  Future<void> _loadFavorites() async {
    villesFavorites = await _db.getVillesFavorites();
    setState(() {});
    _checkFavorite();
  }

  void _checkFavorite() {
    if (villeIdActuelle == null) return;

    villeFavorite = villesFavorites.any((v) => v['id'] == villeIdActuelle);
    setState(() {});
  }

  Future<void> _toggleFavorite() async {
    if (villeIdActuelle == null) return;

    await _db.toggleFavorite(villeIdActuelle!, !villeFavorite);
    await _loadFavorites();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              villeFavorite ? '⭐ Ajouté aux favoris' : '❌ Retiré des favoris'),
        ),
      );
    }
  }

  Future<void> _supprimerVilleFavorite(int villeId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette ville ?'),
        content: const Text(
          'Cette action supprimera également tous les lieux associés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _db.deleteVille(villeId);
      await _loadFavorites();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Ville supprimée'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _setVillePrincipale() async {
    if (villeIdActuelle == null) return;

    await _db.setVillePrincipale(villeIdActuelle!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('🏠 $villeNomActuelle définie comme ville principale')),
      );
    }
  }

  // ==================== CARTE ====================

  void _centrerCarte() {
    if (villeLat != null && villeLon != null) {
      _mapController.move(LatLng(villeLat!, villeLon!), 13.0);
    } else if (userLat != null && userLon != null) {
      _mapController.move(LatLng(userLat!, userLon!), 13.0);
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng position) {
    print('🗺️ Clic sur la carte: ${position.latitude}, ${position.longitude}');

    if (ajoutLieuEnCours) {
      print('➕ Mode ajout lieu activé');
      _ajouterLieuSurCarte(position);
    } else {
      print('ℹ️ Affichage info lieu');
      _afficherInfoLieu(position);
    }
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Explorez Votre Ville',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: [
          if (villeIdActuelle != null)
            IconButton(
              icon: Icon(villeFavorite ? Icons.star : Icons.star_border),
              color: Colors.amber,
              onPressed: _toggleFavorite,
              tooltip: 'Favoris',
            ),
          if (villeIdActuelle != null)
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: _setVillePrincipale,
              tooltip: 'Définir comme ville principale',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ========== BANDEAU MÉTÉO ==========
            WeatherBanner(villeData: villeData, isLoading: isLoading),

            const SizedBox(height: 20),

            // ========== BARRE DE RECHERCHE ==========
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _villeController,
                    decoration: InputDecoration(
                      labelText: 'Rechercher une ville',
                      hintText: 'Paris, Londres, New York...',
                      prefixIcon: const Icon(Icons.search, color: Colors.teal),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide:
                            const BorderSide(color: Colors.teal, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onSubmitted: (_) => _rechercherVille(),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: _rechercherVille,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ========== VILLES FAVORITES (AVEC SUPPRESSION) ==========
            if (villesFavorites.isNotEmpty) ...[
              const Text(
                '⭐ Villes favorites',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: villesFavorites.map((v) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Stack(
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.location_city,
                                size: 18, color: Colors.white),
                            label: Text(v['nom']),
                            backgroundColor: Colors.teal,
                            labelStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            onPressed: () => _chargerVilleDepuisDB(v),
                          ),
                          Positioned(
                            top: -8,
                            right: -8,
                            child: GestureDetector(
                              onTap: () => _supprimerVilleFavorite(v['id']),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ========== CARTE AVEC MARQUEUR SUPER VISIBLE ==========
            Container(
              height: 350,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.teal.shade300, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter:
                        const LatLng(48.8566, 2.3522), // Paris par défaut
                    initialZoom: 13.0,
                    onTap: _onMapTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.explorezvotreville',
                    ),
                    MarkerLayer(
                      markers: [
                        // ========== MARQUEUR VILLE SÉLECTIONNÉE - SUPER VISIBLE AVEC PULSE ==========
                        if (villeLat != null && villeLon != null)
                          Marker(
                            point: LatLng(villeLat!, villeLon!),
                            width: 100,
                            height: 100,
                            child: AnimatedBuilder(
                              animation: _markerController,
                              builder: (context, child) {
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Effet pulse (cercle qui s'agrandit)
                                    Container(
                                      width: 50 + _pulseAnimation.value,
                                      height: 50 + _pulseAnimation.value,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.red.withOpacity(
                                          0.3 - (_pulseAnimation.value / 100),
                                        ),
                                      ),
                                    ),
                                    // Icône principale qui scale
                                    Transform.scale(
                                      scale: _markerAnimation.value,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.red.withOpacity(0.5),
                                              blurRadius: 15,
                                              spreadRadius: 5,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.location_on,
                                          color: Colors.red,
                                          size: 40,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),

                        // Marqueur position GPS utilisateur
                        if (userLat != null && userLon != null)
                          Marker(
                            point: LatLng(userLat!, userLon!),
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.5),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person_pin,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),

                        // Marqueurs des lieux enregistrés
                        ...lieux.map((lieu) {
                          return Marker(
                            point: LatLng(lieu['latitude'], lieu['longitude']),
                            width: 40,
                            height: 40,
                            child: GestureDetector(
                              onTap: () => _centrerSurLieu(lieu),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.5),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.place,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            // ========== FILTRES CATÉGORIES ==========
            const Text(
              '🎯 Catégories',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            CategoryFilter(
              selectedCategory: categorieSelectionnee,
              onCategorySelected: (categorie) {
                setState(() {
                  categorieSelectionnee = categorie;
                });
                _loadLieux();
              },
            ),

            const SizedBox(height: 25),

            // ========== LISTE DES LIEUX ==========
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '📍 Lieux (${lieux.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                TextButton.icon(
                  onPressed: _demarrerAjoutLieu,
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text('Ajouter'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.teal,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (lieux.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.location_off,
                          size: 60, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Text(
                        'Aucun lieu enregistré',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...lieux.map((lieu) {
                // Conversion des images
                List<String> imagesUrls = [];
                if (lieu['images_urls'] != null &&
                    lieu['images_urls'].toString().isNotEmpty) {
                  imagesUrls = (lieu['images_urls'] as String)
                      .split('|||')
                      .where((url) => url.isNotEmpty)
                      .toList();
                }

                return LieuCard(
                  titre: lieu['titre'],
                  categorie: lieu['categorie'],
                  imagesUrls: imagesUrls,
                  note: lieu['note'],
                  onTap: () => _centrerSurLieu(lieu),
                  onDelete: () => _supprimerLieu(lieu['id']),
                );
              }).toList(),

            const SizedBox(height: 30),
          ],
        ),
      ),

      // ========== BOUTON FLOTTANT ==========
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _demarrerAjoutLieu,
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add_location, color: Colors.white),
        label: const Text(
          'Ajouter lieu',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
