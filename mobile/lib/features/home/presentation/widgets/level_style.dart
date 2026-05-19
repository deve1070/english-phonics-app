import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

abstract class LevelStyle {
  static Color color(String level) {
    switch (level.toUpperCase()) {
      case 'LEVEL1':
        return AppColors.teal;
      case 'LEVEL2':
        return AppColors.yellow;
      case 'LEVEL3':
        return AppColors.coral;
      case 'LEVEL4':
        return AppColors.purple;
      case 'LEVEL5':
        return AppColors.orange;
      default:
        return AppColors.teal;
    }
  }

  // FIX: was returning raw enum value e.g. "LEVEL1" — now "Level 1"
  static String label(String level) {
    switch (level.toUpperCase()) {
      case 'LEVEL1':
        return 'Level 1';
      case 'LEVEL2':
        return 'Level 2';
      case 'LEVEL3':
        return 'Level 3';
      case 'LEVEL4':
        return 'Level 4';
      case 'LEVEL5':
        return 'Level 5';
      default:
        // Gracefully handle any unexpected format e.g. "level_1" → "Level 1"
        final cleaned = level
            .replaceAll('_', ' ')
            .replaceAll(RegExp(r'([a-z])([0-9])'), r'$1 $2')
            .toLowerCase();
        return cleaned[0].toUpperCase() + cleaned.substring(1);
    }
  }

  static String emoji(String level) {
    switch (level.toUpperCase()) {
      case 'LEVEL1':
        return '🌱';
      case 'LEVEL2':
        return '🚀';
      case 'LEVEL3':
        return '📖';
      case 'LEVEL4':
        return '🎤';
      case 'LEVEL5':
        return '🏆';
      default:
        return '⭐';
    }
  }
}
