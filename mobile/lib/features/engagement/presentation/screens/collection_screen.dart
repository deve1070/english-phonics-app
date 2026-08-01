import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/mascot/kiki.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/pressable.dart';
import '../../data/engagement_models.dart';
import '../../data/engagement_remote_datasource.dart';
import '../widgets/sound_sticker.dart';

/// The shelf of creatures, one per sound in the curriculum.
///
/// Locked ones are shown, not hidden. A collection whose empty slots are
/// invisible gives a child nothing to aim at — the gaps are the point,
/// and a sleeping creature they can see is a reason to go and practise
/// the sound that wakes it.
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  late final EngagementRemoteDataSource _source =
      EngagementRemoteDataSource(getIt<Dio>());

  Collection? _collection;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final collection = await _source.getCollection();
      if (!mounted) return;
      setState(() => _collection = collection);

      // Acknowledge only after the shelf is on screen, so the server
      // stops flagging these as new exactly when the child has in fact
      // seen them — not when the request happened to be made.
      if (collection.newlyUnlocked.isNotEmpty) {
        await _source.markCollectionSeen();
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message ?? 'Could not load your collection');
    }
  }

  @override
  Widget build(BuildContext context) {
    final collection = _collection;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        backgroundColor: AppColors.parchment,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 18, color: AppColors.ink),
          onPressed: () => context.pop(),
        ),
        title: Text('My Sounds', style: AppTextStyles.headingSmall),
        centerTitle: true,
      ),
      body: switch ((collection, _error)) {
        (_, final String error) => _Message(text: error, onRetry: _load),
        (null, _) => const Center(child: CircularProgressIndicator()),
        (final Collection c, _) => _Shelf(collection: c),
      },
    );
  }
}

class _Shelf extends StatelessWidget {
  final Collection collection;
  const _Shelf({required this.collection});

  @override
  Widget build(BuildContext context) {
    final fresh = collection.newlyUnlocked.toSet();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            child: _Tally(collection: collection),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.86,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = collection.items[index];
                final sticker = SoundSticker(
                  phonemeId: item.phonemeId,
                  symbol: item.symbol,
                  isUnlocked: item.isUnlocked,
                  isRecognised: item.isRecognised,
                  size: 76,
                );
                if (!fresh.contains(item.phonemeId)) return sticker;
                // Newly earned creatures wake up in front of the child
                // rather than simply being there when the page opens.
                return sticker
                    .animate()
                    .scale(
                      begin: const Offset(0.4, 0.4),
                      end: const Offset(1, 1),
                      duration: 420.ms,
                      curve: Curves.elasticOut,
                    )
                    .shimmer(delay: 300.ms, duration: 700.ms);
              },
              childCount: collection.items.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _Tally extends StatelessWidget {
  final Collection collection;
  const _Tally({required this.collection});

  @override
  Widget build(BuildContext context) {
    final fresh = collection.newlyUnlocked.length;
    // Creatures the child has earned by ear but not yet by voice. Naming
    // them gives the shelf a second, nearer thing to aim at than the
    // ninety-sound total, and says exactly what closes the gap.
    final stirring = collection.items
        .where((i) => !i.isUnlocked && i.isRecognised)
        .length;

    return PaperCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: fresh > 0 ? AppColors.honeyLight : AppColors.surface,
      child: Row(
        children: [
          Kiki(
            size: 52,
            mood: fresh > 0 ? KikiMood.celebrating : KikiMood.idle,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fresh > 0
                      ? (fresh == 1 ? 'A new friend!' : '$fresh new friends!')
                      : '${collection.unlocked} of ${collection.total} awake',
                  style: AppTextStyles.headingSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  fresh > 0
                      ? 'You woke them up by learning their sound.'
                      : stirring > 0
                          ? (stirring == 1
                              ? '1 has opened its eyes. Say its sound to wake it.'
                              : '$stirring have opened their eyes. '
                                  'Say their sounds to wake them.')
                          : 'Master a sound to wake up its friend.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;
  const _Message({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Kiki(size: 96, mood: KikiMood.thinking),
            const SizedBox(height: AppSpacing.lg),
            Text(text,
                style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            Pressable(
              onTap: onRetry,
              color: AppColors.leaf,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl, vertical: AppSpacing.md),
              child: Text('Try again',
                  style: AppTextStyles.buttonMedium.copyWith(color: AppColors.onInk)),
            ),
          ],
        ),
      ),
    );
  }
}
