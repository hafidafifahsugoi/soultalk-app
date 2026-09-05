import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// SoulTalk AI logo: gradient circle with a heart icon inside.
/// Pure widget — no asset dependency, scales crisply at any size.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.accent],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: size * 0.35,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.favorite_rounded,
          color: Colors.white,
          size: size * 0.46,
        ),
      ),
    );
  }
}

/// Wordmark + logo lockup.
class AppLogoLockup extends StatelessWidget {
  const AppLogoLockup({
    super.key,
    this.logoSize = 40,
    this.fontSize = 22,
    this.color,
  });

  final double logoSize;
  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLogo(size: logoSize),
        const SizedBox(width: 12),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Soul',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: fontSize,
                      color: color ?? AppColors.foreground,
                    ),
              ),
              TextSpan(
                text: 'Talk',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: fontSize,
                      color: AppColors.primary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
