import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/mascot/kiki.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/pressable.dart';
import '../../data/engagement_models.dart';
import '../../data/engagement_remote_datasource.dart';

/// The bookshelf. Stories a child can read using only sounds they have
/// mastered, and the ones still waiting.
///
/// A locked book shows its title and the sound that would open it. That
/// is the difference between a wall and a door: "learn /sh/ and this one
/// opens" is an errand a six-year-old can run, where a padlock with no
/// explanation is just a place they are not allowed.
class StoryShelfScreen extends StatefulWidget {
  const StoryShelfScreen({super.key});

  @override
  State<StoryShelfScreen> createState() => _StoryShelfScreenState();
}

class _StoryShelfScreenState extends State<StoryShelfScreen> {
  late final EngagementRemoteDataSource _source =
      EngagementRemoteDataSource(getIt<Dio>());

  StoryShelf? _shelf;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final shelf = await _source.getStories();
      if (mounted) setState(() => _shelf = shelf);
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _error = e.message ?? 'Could not load your stories');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shelf = _shelf;

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
        title: Text('My Stories', style: AppTextStyles.headingSmall),
        centerTitle: true,
      ),
      body: switch ((shelf, _error)) {
        (_, final String error) => _Centred(text: error),
        (null, _) => const Center(child: CircularProgressIndicator()),
        (final StoryShelf s, _) when s.stories.isEmpty =>
          const _Centred(text: 'No stories yet. Check back soon!'),
        (final StoryShelf s, _) => ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
            children: [
              _ShelfHeader(shelf: s),
              const SizedBox(height: AppSpacing.lg),
              for (final story in s.stories) ...[
                _StoryTile(
                  story: story,
                  onOpen: story.isUnlocked
                      ? () => _openStory(context, story)
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
      },
    );
  }

  void _openStory(BuildContext context, Story story) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => StoryReaderScreen(story: story)),
    );
  }
}

class _ShelfHeader extends StatelessWidget {
  final StoryShelf shelf;
  const _ShelfHeader({required this.shelf});

  @override
  Widget build(BuildContext context) {
    final none = shelf.unlocked == 0;
    return PaperCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Kiki(size: 52, mood: none ? KikiMood.encouraging : KikiMood.idle),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              none
                  ? 'Master some sounds and your first story will open.'
                  : 'You can read ${shelf.unlocked} of ${shelf.total}.',
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryTile extends StatelessWidget {
  final Story story;
  final VoidCallback? onOpen;

  const _StoryTile({required this.story, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final open = story.isUnlocked;
    return Pressable(
      onTap: onOpen,
      color: open ? AppColors.surface : AppColors.surfaceSunken,
      padding: const EdgeInsets.all(AppSpacing.md),
      semanticLabel: open
          ? 'Read ${story.title}'
          : '${story.title}, locked. Master ${story.blockingPhoneme} to open it',
      child: Row(
        children: [
          Container(
            width: 46,
            height: 58,
            decoration: BoxDecoration(
              color: open ? AppColors.leaf : AppColors.dormant,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(AppRadius.sm),
                bottomRight: Radius.circular(AppRadius.sm),
                topLeft: Radius.circular(2),
                bottomLeft: Radius.circular(2),
              ),
              border: Border.all(
                  color: AppColors.border, width: AppBorders.standard),
            ),
            child: Icon(
              open ? Icons.menu_book_rounded : Icons.lock_rounded,
              size: 20,
              color: AppColors.onInk,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  story.title,
                  style: AppTextStyles.headingSmall.copyWith(
                    fontSize: 17,
                    color: open ? AppColors.ink : AppColors.inkSoft,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  open
                      ? '${story.wordCount} words'
                      : story.blockingPhoneme != null
                          ? 'Learn ${story.blockingPhoneme} to open this'
                          : 'Keep practising to open this',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: open ? AppColors.inkSoft : AppColors.honey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The reading page itself.
///
/// One story, set large, with nothing else on the screen. No score, no
/// timer, no next button competing for attention — this is the reward,
/// and the only thing being asked of the child is to read it.
class StoryReaderScreen extends StatelessWidget {
  final Story story;
  const StoryReaderScreen({super.key, required this.story});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        backgroundColor: AppColors.parchment,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 18, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(story.title, style: AppTextStyles.headingSmall),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PaperCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                story.content ?? '',
                // readingText, not the handwriting face: this is the thing
                // being decoded, so the letterforms have to be canonical.
                style: AppTextStyles.readingText.copyWith(fontSize: 26, height: 1.7),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                const Kiki(size: 54, mood: KikiMood.listening),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Read it out loud to Kiki.',
                    style: AppTextStyles.mascotSpeech
                        .copyWith(fontSize: 19, color: AppColors.inkSoft),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Pressable(
              onTap: () => context.push(
                '${AppRoutes.practice}/${story.exerciseId}',
                extra: {'content': story.content, 'type': 'PARAGRAPH'},
              ),
              color: AppColors.leaf,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: Text(
                  'Read it to Kiki',
                  style: AppTextStyles.buttonMedium.copyWith(color: AppColors.onInk),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Centred extends StatelessWidget {
  final String text;
  const _Centred({required this.text});

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
          ],
        ),
      ),
    );
  }
}
