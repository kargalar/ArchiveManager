import 'package:flutter/material.dart';
import '../../../models/tag.dart';

/// A reusable widget to display tags as colored chips
class TagChips extends StatelessWidget {
  final List<Tag> tags;
  final double fontSize;
  final double padding;
  final bool showShadow;

  const TagChips({
    super.key,
    required this.tags,
    this.fontSize = 10,
    this.padding = 6,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      children: tags
          .map((tag) => Container(
                padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding / 3),
                decoration: BoxDecoration(
                  color: tag.color,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white24, width: 1),
                  boxShadow: showShadow
                      ? [
                          const BoxShadow(
                            color: Colors.black,
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  tag.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ))
          .toList(),
    );
  }
}
