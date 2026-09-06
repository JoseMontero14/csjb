import 'package:flutter/material.dart';
import '../utils/theme.dart';

enum BadgeSize { small, medium, large }

class UrgencyBadge extends StatelessWidget {
  const UrgencyBadge(
    this.level, {
    super.key,
    this.size = BadgeSize.medium,
    this.showIcon = true,
    this.showLabel = true,
  });

  final UrgencyLevel level;
  final BadgeSize size;
  final bool showIcon;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final (iconSize, fontSize, hPad, vPad) = switch (size) {
      BadgeSize.small => (12.0, 10.0, 8.0, 3.0),
      BadgeSize.medium => (14.0, 12.0, 10.0, 4.0),
      BadgeSize.large => (16.0, 14.0, 14.0, 6.0),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: level.backgroundColor,
        borderRadius: AppRadius.fullBr,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(level.icon, color: level.color, size: iconSize),
            if (showLabel) const SizedBox(width: 4),
          ],
          if (showLabel)
            Text(
              level.label,
              style: textTheme.labelMedium?.copyWith(
                color: level.color,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
