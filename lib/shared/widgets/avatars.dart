import 'package:flutter/material.dart';

import '../../data/models/expense.dart';
import '../../core/theme/app_theme.dart';

/// Compact avatar that shows initials when there is no image, so members are
/// always distinguishable without loading remote images.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    this.initials,
    this.imageUrl,
    this.size = 40,
    this.highlight = false,
  });

  final String? initials;
  final String? imageUrl;
  final double size;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String text = (initials ?? '?').trim();

    final List<Color> palette = <Color>[
      const Color(0xFF0F766E),
      const Color(0xFF1D4ED8),
      const Color(0xFFB45309),
      const Color(0xFF7C3AED),
      const Color(0xFF0E7490),
      const Color(0xFFBE185D),
    ];
    final Color base =
        palette[text.codeUnits.fold<int>(0, (a, b) => a + b) % palette.length];

    final Widget circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: imageUrl == null ? base.withValues(alpha: 0.14) : null,
        shape: BoxShape.circle,
        border: Border.all(
          color: highlight
              ? theme.colorScheme.primary
              : base.withValues(alpha: 0.28),
          width: highlight ? 2 : 1,
        ),
        image: imageUrl == null
            ? null
            : DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
                onError: (_, _) {},
              ),
      ),
      alignment: Alignment.center,
      child: imageUrl != null
          ? null
          : Text(
              text.isEmpty ? '?' : text.substring(0, text.length.clamp(0, 2)),
              style: theme.textTheme.labelMedium?.copyWith(
                color: base,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.36,
              ),
            ),
    );

    return Semantics(label: 'Member avatar', child: circle);
  }
}

/// Overlapping avatars with a "+N" overflow chip.
class MemberStack extends StatelessWidget {
  const MemberStack({
    super.key,
    required this.members,
    this.maxVisible = 4,
    this.size = 30,
  });

  final List<TripMember> members;
  final int maxVisible;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<TripMember> visible = members.take(maxVisible).toList();
    final int overflow = members.length - visible.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < visible.length; i++)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
              ),
              child: MemberAvatar(initials: visible[i].initials, size: size),
            ),
          ),
        if (overflow > 0)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text('+$overflow', style: theme.textTheme.labelSmall),
            ),
          ),
      ],
    );
  }
}

/// Circular monogram used for the signed-in user in headers.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.initials,
    this.size = 36,
    this.onTap,
  });

  final String initials;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget avatar = MemberAvatar(initials: initials, size: size);
    if (onTap == null) return avatar;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(padding: const EdgeInsets.all(2), child: avatar),
    );
  }
}
