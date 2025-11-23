import 'package:flutter/material.dart';
import 'package:card_swiper/card_swiper.dart';

/// =========================================================
/// LIEU CARD - Carte de lieu avec CAROUSEL de photos
/// =========================================================
class LieuCard extends StatelessWidget {
  final String titre;
  final String categorie;
  final List<String>? imagesUrls; // ← MODIFIÉ : liste d'images
  final double? note;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const LieuCard({
    Key? key,
    required this.titre,
    required this.categorie,
    this.imagesUrls,
    this.note,
    required this.onTap,
    this.onDelete,
  }) : super(key: key);

  IconData _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'musee':
        return Icons.museum;
      case 'restaurant':
        return Icons.restaurant;
      case 'parc':
        return Icons.park;
      case 'monument':
        return Icons.account_balance;
      case 'stade':
        return Icons.stadium;
      default:
        return Icons.place;
    }
  }

  Color _getCategoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'musee':
        return Colors.purple;
      case 'restaurant':
        return Colors.orange;
      case 'parc':
        return Colors.green;
      case 'monument':
        return Colors.brown;
      case 'stade':
        return Colors.red;
      default:
        return Colors.teal;
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getCategoryColor(categorie).withOpacity(0.6),
            _getCategoryColor(categorie).withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          _getCategoryIcon(categorie),
          size: 60,
          color: Colors.white.withOpacity(0.7),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImages = imagesUrls != null && imagesUrls!.isNotEmpty;
    final validImages = hasImages
        ? imagesUrls!.where((url) => url.isNotEmpty).toList()
        : <String>[];

    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CAROUSEL DE PHOTOS ou placeholder
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: validImages.isNotEmpty
                      ? Swiper(
                          itemBuilder: (BuildContext context, int index) {
                            return Image.network(
                              validImages[index],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildPlaceholder();
                              },
                            );
                          },
                          itemCount: validImages.length,
                          autoplay: validImages.length > 1,
                          pagination: validImages.length > 1
                              ? const SwiperPagination()
                              : null,
                          control: validImages.length > 1
                              ? const SwiperControl()
                              : null,
                        )
                      : _buildPlaceholder(),
                ),
                // Indicateur nombre de photos
                if (validImages.length > 1)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_library,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${validImages.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Badge catégorie
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(categorie),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getCategoryIcon(categorie),
                            color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          categorie.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Bouton supprimer
                if (onDelete != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.white, size: 20),
                        onPressed: onDelete,
                      ),
                    ),
                  ),
              ],
            ),
            // Infos
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titre,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (note != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < note!.round()
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 18,
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          note!.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
