import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Popi peeking from top
        Image.asset(
          'assets/images/popi.png',
          height: 110,
          errorBuilder: (_, __, ___) =>
              const Text('🐣', style: TextStyle(fontSize: 64)),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: AppTextStyles.displaySmall.copyWith(color: AppColors.coral),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
