import 'package:flutter/material.dart';
import '../../../models/photo.dart';

/// A reusable widget for the favorite button that toggles photo favorite status
class FavoriteIconButton extends StatelessWidget {
  final Photo photo;
  final VoidCallback onPressed;
  final String? tooltip;
  final double? iconSize;

  const FavoriteIconButton({
    super.key,
    required this.photo,
    required this.onPressed,
    this.tooltip,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        photo.isFavorite ? Icons.favorite : Icons.favorite_border,
        color: photo.isFavorite ? Colors.red : Colors.white70,
        size: iconSize,
      ),
      onPressed: onPressed,
      tooltip: tooltip ?? 'Toggle Favorite (F)',
    );
  }
}

/// A reusable widget for the selection button
class SelectionIconButton extends StatelessWidget {
  final Photo photo;
  final VoidCallback onPressed;
  final String? tooltip;
  final double? iconSize;

  const SelectionIconButton({
    super.key,
    required this.photo,
    required this.onPressed,
    this.tooltip,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        photo.isSelected ? Icons.check_circle : Icons.check_circle_outline,
        color: photo.isSelected ? Colors.blue : Colors.white70,
        size: iconSize,
      ),
      onPressed: onPressed,
      tooltip: tooltip ?? (photo.isSelected ? 'Seçimi Kaldır (Space/Enter)' : 'Seç (Space/Enter)'),
    );
  }
}

/// A reusable widget for info toggle button
class InfoIconButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onPressed;
  final String? tooltip;
  final double? iconSize;

  const InfoIconButton({
    super.key,
    required this.isActive,
    required this.onPressed,
    this.tooltip,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.info_outline,
        color: isActive ? Colors.blue : Colors.white70,
        size: iconSize,
      ),
      onPressed: onPressed,
      tooltip: tooltip ?? (isActive ? 'Hide Info (Ctrl)' : 'Show Info (Ctrl)'),
    );
  }
}

/// A reusable widget for notes toggle button
class NotesIconButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onPressed;
  final String? tooltip;
  final double? iconSize;

  const NotesIconButton({
    super.key,
    required this.isActive,
    required this.onPressed,
    this.tooltip,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.note_outlined,
        color: isActive ? Colors.blue : Colors.white70,
        size: iconSize,
      ),
      onPressed: onPressed,
      tooltip: tooltip ?? (isActive ? 'Hide Notes (N)' : 'Show Notes (N)'),
    );
  }
}

/// A reusable widget for rating display
class RatingDisplay extends StatelessWidget {
  final int rating;
  final double iconSize;
  final double fontSize;

  const RatingDisplay({
    super.key,
    required this.rating,
    this.iconSize = 18,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    if (rating <= 0) return const SizedBox.shrink();

    return Row(
      children: [
        Icon(Icons.star, size: iconSize, color: Colors.amber),
        const SizedBox(width: 4),
        Text(
          rating.toString(),
          style: TextStyle(color: Colors.amber, fontSize: fontSize),
        ),
      ],
    );
  }
}
