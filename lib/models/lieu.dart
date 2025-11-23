/// =========================================================
/// MODÈLE LIEU - Représente un lieu d'intérêt (MULTI-PHOTOS)
/// =========================================================
class Lieu {
  final int? id;
  final String titre;
  final String categorie;
  final List<String> imagesUrls; // ← MODIFIÉ : plusieurs photos
  final double latitude;
  final double longitude;
  final String? commentaire;
  final double? note;
  final int villeId;

  Lieu({
    this.id,
    required this.titre,
    required this.categorie,
    this.imagesUrls = const [],
    required this.latitude,
    required this.longitude,
    this.commentaire,
    this.note,
    required this.villeId,
  });

  factory Lieu.fromMap(Map<String, dynamic> map) => Lieu(
        id: map['id'],
        titre: map['titre'],
        categorie: map['categorie'],
        imagesUrls: map['images_urls'] != null
            ? (map['images_urls'] as String).split('|||')
            : [],
        latitude: map['latitude'],
        longitude: map['longitude'],
        commentaire: map['commentaire'],
        note: map['note'],
        villeId: map['ville_id'],
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'titre': titre,
        'categorie': categorie,
        'images_urls': imagesUrls.join('|||'), // ← sépare par |||
        'latitude': latitude,
        'longitude': longitude,
        'commentaire': commentaire,
        'note': note,
        'ville_id': villeId,
      };
}
