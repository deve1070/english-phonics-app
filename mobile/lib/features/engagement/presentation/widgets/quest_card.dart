import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/mascot/kiki.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/pressable.dart';
import '../../data/engagement_models.dart';

/// Today's three things, on the home screen above everything else.
///
/// The card exists to answer one question a child actually has — "what am
/// I doing today?" — and to make the answer finishable. Three rows, each
/// either done or not, and a state at the end that says today is
/// complete. Nothing here counts minutes or invites another round: the
/// parent's screen-time cap and this card have to agree, and a card that
/// nagged for more would be fighting a feature the app already has.
class QuestCard extends StatelessWidget {
  final DailyQuest quest;
  final void Function(QuestItem item) onTapItem;

  const QuestCard({super.key, required this.quest, required this.onTapItem});

  @override
  Widget build(BuildContext context) {
    if (quest.isEmpty) return const SizedBox.shrink();

    return PaperCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: quest.isComplete ? AppColors.leafLight : AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(quest: quest),
          const SizedBox(height: AppSpacing.md),
          for (final item in quest.items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _QuestRow(
                item: item,
                onTap: item.completed ? null : () => onTapItem(item),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final DailyQuest quest;
  const _Header({required this.quest});

  @override
  Widget build(BuildContext context) {
    if (quest.isComplete) {
      return const Row(
        children: [
          Kiki(size: 46, mood: KikiMood.celebrating),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              // An ending, not a prompt to keep going.
              "That's today done!",
              style: AppTextStyles.headingSmall,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 320.ms);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Text('Today', style: AppTextStyles.headingSmall),
        ),
        // Progress as "1 of 3", not a percentage or a bar. A child can
        // count three; a bar at 33% means nothing to them.
        Text(
          '${quest.completedCount} of ${quest.items.length}',
          style: AppTextStyles.label.copyWith(color: AppColors.inkSoft),
        ),
      ],
    );
  }
}

class _QuestRow extends StatelessWidget {
  final QuestItem item;
  final VoidCallback? onTap;

  const _QuestRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final done = item.completed;
    return Pressable(
      onTap: onTap,
      color: done ? AppColors.leafLight : AppColors.surface,
      borderColor: done ? AppColors.leaf : AppColors.border,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      semanticLabel: done
          ? '${item.slot.label}, ${item.content}, done'
          : '${item.slot.label}, ${item.content}',
      child: Row(
        children: [
          _Tick(done: done),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.slot.label,
                  style: AppTextStyles.label.copyWith(
                    color: done ? AppColors.leafDark : AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.content,
                  style: AppTextStyles.readingText.copyWith(fontSize: 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!done)
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
        ],
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  final bool done;
  const _Tick({required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: done ? AppColors.leaf : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: done ? AppColors.leaf : AppColors.borderSoft,
          width: AppBorders.standard,
        ),
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 16, color: AppColors.onInk)
          : null,
    );
  }
}
