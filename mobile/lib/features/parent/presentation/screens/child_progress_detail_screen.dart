import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';

// ── Data models ───────────────────────────────────────────────────
class PhonemeProgressModel {
  final int phonemeId;
  final String symbol;
  final int order;
  final bool isMastered;
  final double? avgScore;
  final int attempts;

  const PhonemeProgressModel({
    required this.phonemeId,
    required this.symbol,
    required this.order,
    required this.isMastered,
    required this.avgScore,
    required this.attempts,
  });

  factory PhonemeProgressModel.fromJson(Map<String, dynamic> j) =>
      PhonemeProgressModel(
        phonemeId: j['phoneme_id'] as int,
        symbol: j['symbol'] as String,
        order: j['order'] as int,
        isMastered: j['is_mastered'] as bool,
        avgScore: (j['avg_score'] as num?)?.toDouble(),
        attempts: j['attempts'] as int,
      );
}

class WeeklyReportModel {
  final String summaryText;
  final List<String> phonemesMastered;
  final List<String> phonemesStruggling;
  final double? avgPronunciationScore;
  final int sessionsCompleted;
  final double totalMinutes;
  final String? recommendedFocus;
  final String? encouragementMessage;

  const WeeklyReportModel({
    required this.summaryText,
    required this.phonemesMastered,
    required this.phonemesStruggling,
    this.avgPronunciationScore,
    required this.sessionsCompleted,
    required this.totalMinutes,
    this.recommendedFocus,
    this.encouragementMessage,
  });

  factory WeeklyReportModel.fromJson(Map<String, dynamic> j) =>
      WeeklyReportModel(
        summaryText: j['summary_text'] as String,
        phonemesMastered: List<String>.from(j['phonemes_mastered'] ?? []),
        phonemesStruggling: List<String>.from(j['phonemes_struggling'] ?? []),
        avgPronunciationScore:
            (j['avg_pronunciation_score'] as num?)?.toDouble(),
        sessionsCompleted: j['sessions_completed'] as int,
        totalMinutes: (j['total_minutes'] as num).toDouble(),
        recommendedFocus: j['recommended_focus'] as String?,
        encouragementMessage: j['encouragement_message'] as String?,
      );
}

// ── State ─────────────────────────────────────────────────────────
abstract class ChildDetailState extends Equatable {
  const ChildDetailState();
  @override
  List<Object?> get props => [];
}

class ChildDetailLoading extends ChildDetailState {
  const ChildDetailLoading();
}

class ChildDetailLoaded extends ChildDetailState {
  final Map<String, dynamic> progressData;
  final WeeklyReportModel? weeklyReport;

  const ChildDetailLoaded({
    required this.progressData,
    this.weeklyReport,
  });

  @override
  List<Object?> get props => [progressData, weeklyReport];
}

class ChildDetailError extends ChildDetailState {
  final String message;
  const ChildDetailError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── Cubit ─────────────────────────────────────────────────────────
class ChildDetailCubit extends Cubit<ChildDetailState> {
  final Dio _dio;
  final int childId;

  ChildDetailCubit(this._dio, this.childId) : super(const ChildDetailLoading());

  factory ChildDetailCubit.create(int childId) =>
      ChildDetailCubit(getIt<Dio>(), childId);

  Future<void> load() async {
    emit(const ChildDetailLoading());
    try {
      final results = await Future.wait([
        _dio.get('/parents/children/$childId/progress'),
        _dio.get('/parents/children/$childId/weekly-report'),
      ]);

      final progress = results[0].data as Map<String, dynamic>;
      WeeklyReportModel? report;
      try {
        report =
            WeeklyReportModel.fromJson(results[1].data as Map<String, dynamic>);
      } catch (_) {}

      emit(ChildDetailLoaded(progressData: progress, weeklyReport: report));
    } on DioException catch (e) {
      emit(ChildDetailError(e.message ?? 'Failed to load child data'));
    } catch (e) {
      emit(ChildDetailError(e.toString()));
    }
  }

  Future<void> updateGoals({
    int? dailyMinutes,
    int? lessonsPerWeek,
    int? maxDailyMinutes,
  }) async {
    try {
      await _dio.put(
        '/parents/children/$childId/goals',
        data: {
          if (dailyMinutes != null) 'daily_minutes_target': dailyMinutes,
          if (lessonsPerWeek != null) 'lessons_per_week': lessonsPerWeek,
          if (maxDailyMinutes != null) 'max_daily_minutes': maxDailyMinutes,
        },
      );
      await load();
    } catch (_) {}
  }
}

// ── Screen ────────────────────────────────────────────────────────
class ChildProgressDetailScreen extends StatelessWidget {
  final int childId;
  const ChildProgressDetailScreen({super.key, required this.childId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ChildDetailCubit.create(childId)..load(),
      child: const _ChildDetailView(),
    );
  }
}

class _ChildDetailView extends StatelessWidget {
  const _ChildDetailView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Child's Progress", style: AppTextStyles.headingSmall),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<ChildDetailCubit>().load(),
          ),
        ],
      ),
      body: BlocBuilder<ChildDetailCubit, ChildDetailState>(
        builder: (context, state) {
          if (state is ChildDetailLoading) {
            return const Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.coral)),
            );
          }
          if (state is ChildDetailError) {
            return Center(child: Text(state.message));
          }
          if (state is ChildDetailLoaded) {
            return _DetailContent(state: state);
          }
          return const SizedBox();
        },
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  final ChildDetailLoaded state;
  const _DetailContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final d = state.progressData;
    final avgScore = (d['avg_pronunciation_score'] as num?)?.toDouble();
    final minutesWeek = (d['minutes_this_week'] as num?)?.toDouble() ?? 0;
    final phonemes = (d['phoneme_progress'] as List<dynamic>? ?? [])
        .map((p) => PhonemeProgressModel.fromJson(p as Map<String, dynamic>))
        .toList();
    final mastered = phonemes.where((p) => p.isMastered).length;
    final attempted = phonemes.where((p) => p.attempts > 0).length;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // ── Weekly report card ──────────────────────────────────
        if (state.weeklyReport != null)
          _WeeklyReportCard(report: state.weeklyReport!)
              .animate()
              .fadeIn(duration: 400.ms),

        const SizedBox(height: AppSpacing.lg),

        // ── Stats row ───────────────────────────────────────────
        Row(
          children: [
            _StatBox(
                emoji: '🎯',
                value: avgScore != null ? '${avgScore.toInt()}%' : '--',
                label: 'Avg Score',
                color: AppColors.teal),
            const SizedBox(width: AppSpacing.md),
            _StatBox(
                emoji: '⏱️',
                value: '${minutesWeek.toInt()} min',
                label: 'This Week',
                color: AppColors.purple),
            const SizedBox(width: AppSpacing.md),
            _StatBox(
                emoji: '✅',
                value: '$mastered',
                label: 'Mastered',
                color: AppColors.green),
          ],
        ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

        const SizedBox(height: AppSpacing.xl),

        // ── Learning goals ───────────────────────────────────────
        _GoalsCard(childId: d['child_id'] as int)
            .animate(delay: 150.ms)
            .fadeIn(duration: 400.ms),

        const SizedBox(height: AppSpacing.xl),

        // ── Phoneme progress ─────────────────────────────────────
        const Text('Phoneme Progress', style: AppTextStyles.headingSmall)
            .animate(delay: 200.ms)
            .fadeIn(duration: 400.ms),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '$attempted of ${phonemes.length} phonemes attempted · $mastered mastered',
          style: AppTextStyles.bodySmall,
        ).animate(delay: 220.ms).fadeIn(duration: 400.ms),
        const SizedBox(height: AppSpacing.md),

        ...phonemes.map((p) => _PhonemeRow(phoneme: p)
            .animate(delay: Duration(milliseconds: 250 + p.order * 20))
            .fadeIn(duration: 300.ms)),
      ],
    );
  }
}

// ── Weekly report card ────────────────────────────────────────────
class _WeeklyReportCard extends StatelessWidget {
  final WeeklyReportModel report;
  const _WeeklyReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4ECDC4), Color(0xFF38B2A9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.teal.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📊', style: TextStyle(fontSize: 20)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'This Week\'s Report',
                style: AppTextStyles.headingSmall.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            report.summaryText,
            style: AppTextStyles.bodyMedium
                .copyWith(color: Colors.white.withValues(alpha: 0.95)),
          ),
          if (report.encouragementMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  const Text('💬', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      report.encouragementMessage!,
                      style:
                          AppTextStyles.bodySmall.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (report.sessionsCompleted > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _ReportPill(text: '${report.sessionsCompleted} sessions'),
                const SizedBox(width: AppSpacing.sm),
                _ReportPill(text: '${report.totalMinutes.toInt()} min'),
                if (report.phonemesMastered.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                    child: _ReportPill(
                      text: '${report.phonemesMastered.length} mastered',
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportPill extends StatelessWidget {
  final String text;
  const _ReportPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(text,
          style:
              AppTextStyles.label.copyWith(color: Colors.white, fontSize: 11)),
    );
  }
}

// ── Goals card ────────────────────────────────────────────────────
class _GoalsCard extends StatefulWidget {
  final int childId;
  const _GoalsCard({required this.childId});

  @override
  State<_GoalsCard> createState() => _GoalsCardState();
}

class _GoalsCardState extends State<_GoalsCard> {
  int _dailyMins = 15;
  int _maxMins = 30;
  int _lessonsPerWeek = 3;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🎯', style: TextStyle(fontSize: 18)),
              SizedBox(width: AppSpacing.sm),
              Text('Learning Goals', style: AppTextStyles.headingSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _GoalSlider(
            label: 'Daily goal',
            value: _dailyMins.toDouble(),
            min: 5,
            max: 60,
            divisions: 11,
            unit: 'min',
            color: AppColors.teal,
            onChanged: (v) => setState(() => _dailyMins = v.toInt()),
          ),
          _GoalSlider(
            label: 'Daily limit (screen time)',
            value: _maxMins.toDouble(),
            min: 10,
            max: 120,
            divisions: 11,
            unit: 'min',
            color: AppColors.coral,
            onChanged: (v) => setState(() => _maxMins = v.toInt()),
          ),
          _GoalSlider(
            label: 'Lessons per week',
            value: _lessonsPerWeek.toDouble(),
            min: 1,
            max: 7,
            divisions: 6,
            unit: 'lessons',
            color: AppColors.purple,
            onChanged: (v) => setState(() => _lessonsPerWeek = v.toInt()),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.read<ChildDetailCubit>().updateGoals(
                    dailyMinutes: _dailyMins,
                    maxDailyMinutes: _maxMins,
                    lessonsPerWeek: _lessonsPerWeek,
                  ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              child: const Text('Save Goals'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String unit;
  final Color color;
  final ValueChanged<double> onChanged;

  const _GoalSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.unit,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.label),
            Text('${value.toInt()} $unit',
                style: AppTextStyles.label.copyWith(color: color)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            thumbColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.2),
            overlayColor: color.withValues(alpha: 0.1),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ── Phoneme row ───────────────────────────────────────────────────
class _PhonemeRow extends StatelessWidget {
  final PhonemeProgressModel phoneme;
  const _PhonemeRow({required this.phoneme});

  @override
  Widget build(BuildContext context) {
    final color = phoneme.isMastered
        ? AppColors.green
        : phoneme.avgScore != null && phoneme.avgScore! >= 60
            ? AppColors.teal
            : phoneme.attempts > 0
                ? AppColors.coral
                : AppColors.border;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Center(
              child: Text(
                phoneme.symbol,
                style: AppTextStyles.bodyLarge
                    .copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      phoneme.attempts > 0
                          ? '${phoneme.attempts} attempts'
                          : 'Not started',
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                    ),
                    if (phoneme.avgScore != null)
                      Text(
                        '${phoneme.avgScore!.toInt()}%',
                        style: AppTextStyles.label.copyWith(color: color),
                      ),
                  ],
                ),
                if (phoneme.avgScore != null) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: LinearProgressIndicator(
                      value: phoneme.avgScore! / 100,
                      backgroundColor: color.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 5,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.md),

          Icon(
            phoneme.isMastered
                ? Icons.check_circle_rounded
                : phoneme.attempts > 0
                    ? Icons.circle_outlined
                    : Icons.lock_outline_rounded,
            color: color,
            size: 20,
          ),
        ],
      ),
    );
  }
}

// ── Stat box ──────────────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final Color color;

  const _StatBox({
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(value,
                style: AppTextStyles.headingSmall
                    .copyWith(color: color, fontSize: 16)),
            Text(label,
                style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
