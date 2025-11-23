import 'package:flutter/material.dart';

/// =========================================================
/// CATEGORY FILTER - Filtres par catégorie stylés
/// =========================================================
class CategoryFilter extends StatelessWidget {
  final String? selectedCategory;
  final Function(String?) onCategorySelected;

  const CategoryFilter({
    Key? key,
    required this.selectedCategory,
    required this.onCategorySelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final categories = [
      {
        'label': 'Tous',
        'value': null,
        'icon': Icons.grid_view,
        'color': Colors.teal
      },
      {
        'label': 'Musées',
        'value': 'musee',
        'icon': Icons.museum,
        'color': Colors.purple
      },
      {
        'label': 'Restaurants',
        'value': 'restaurant',
        'icon': Icons.restaurant,
        'color': Colors.orange
      },
      {
        'label': 'Parcs',
        'value': 'parc',
        'icon': Icons.park,
        'color': Colors.green
      },
      {
        'label': 'Monuments',
        'value': 'monument',
        'icon': Icons.account_balance,
        'color': Colors.brown
      },
      {
        'label': 'Stades',
        'value': 'stade',
        'icon': Icons.stadium,
        'color': Colors.red
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          final isSelected = selectedCategory == category['value'];
          final color = category['color'] as Color;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: FilterChip(
                selected: isSelected,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      category['icon'] as IconData,
                      size: 20,
                      color: isSelected ? Colors.white : color,
                    ),
                    const SizedBox(width: 6),
                    Text(category['label'] as String),
                  ],
                ),
                selectedColor: color,
                backgroundColor: color.withOpacity(0.1),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : color,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 13,
                ),
                elevation: isSelected ? 4 : 0,
                shadowColor: color.withOpacity(0.5),
                onSelected: (selected) {
                  onCategorySelected(
                    selected ? category['value'] as String? : null,
                  );
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
