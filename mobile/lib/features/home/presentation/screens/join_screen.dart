import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/token_storage.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';

// ── State ──────────────────────────────────────────────────────────
abstract class JoinState extends Equatable {
  const JoinState();
  @override
  List<Object?> get props => [];
}

class JoinLoading extends JoinState {
  const JoinLoading();
}

class JoinSuccess extends JoinState {
  final String childName;
  final int? lastLessonId;
  const JoinSuccess({required this.childName, this.lastLessonId});
  @override
  List<Object?> get props => [childName, lastLessonId];
}

class JoinError extends JoinState {
  final String message;
  const JoinError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── Cubit ──────────────────────────────────────────────────────────
class JoinCubit extends Cubit<JoinState> {
  final Dio _dio;
  final TokenStorage _tokenStorage;

  JoinCubit(this._dio, this._tokenStorage) : super(const JoinLoading());

  factory JoinCubit.create() => JoinCubit(getIt<Dio>(), getIt<TokenStorage>());

  Future<void> redeem(String token) async {
    if (token.isEmpty) {
      emit(const JoinError(
          'Invalid invite link. Ask your parent to share the link again.'));
      return;
    }
    emit(const JoinLoading());
    try {
      final response = await _dio.post(
        ApiConstants.joinWithInvite,
        data: {'token': token},
      );

      final accessToken = response.data['access_token'] as String;
      await _tokenStorage.saveTokens(accessToken: accessToken);
      await _tokenStorage.saveUserRole('STUDENT');
      await _tokenStorage.saveSubscriptionStatus('TRIAL');

      final childName = response.data['child_name'] as String? ?? 'there';
      final lastLessonId = response.data['last_lesson_id'] as int?;

      emit(JoinSuccess(childName: childName, lastLessonId: lastLessonId));
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'];
      emit(JoinError(
        detail?.toString() ??
            'This invite link is invalid or has expired. '
                'Ask your parent to generate a new one.',
      ));
    } catch (_) {
      emit(const JoinError('Something went wrong. Please try again.'));
    }
  }
}

// ── Screen ─────────────────────────────────────────────────────────
class JoinScreen extends StatelessWidget {
  final String token;
  const JoinScreen({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => JoinCubit.create()..redeem(token),
      child: const _JoinView(),
    );
  }
}

class _JoinView extends StatelessWidget {
  const _JoinView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocConsumer<JoinCubit, JoinState>(
        listener: (context, state) {
          if (state is JoinSuccess) {
            Future.delayed(const Duration(seconds: 2), () {
              if (context.mounted) {
                if (state.lastLessonId != null) {
                  context.go('/lessons/${state.lastLessonId}');
                } else {
                  context.go(AppRoutes.home);
                }
              }
            });
          }
        },
        builder: (context, state) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (state is JoinLoading) _LoadingView(),
                if (state is JoinSuccess) _SuccessView(state: state),
                if (state is JoinError) _ErrorView(state: state),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('🔗', style: TextStyle(fontSize: 64))
            .animate()
            .scale(duration: 500.ms, curve: Curves.elasticOut),
        const SizedBox(height: AppSpacing.xl),
        Text('Setting up your learning...',
                style: AppTextStyles.headingMedium, textAlign: TextAlign.center)
            .animate(delay: 200.ms)
            .fadeIn(duration: 300.ms),
        const SizedBox(height: AppSpacing.xl),
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppColors.teal),
          strokeWidth: 3,
        ),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  final JoinSuccess state;
  const _SuccessView({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('🎉', style: TextStyle(fontSize: 72))
            .animate()
            .scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: AppSpacing.xl),
        Text('Welcome, ${state.childName}!',
                style:
                    AppTextStyles.displayMedium.copyWith(color: AppColors.teal),
                textAlign: TextAlign.center)
            .animate(delay: 200.ms)
            .fadeIn(duration: 300.ms),
        const SizedBox(height: AppSpacing.md),
        Text(
          state.lastLessonId != null
              ? 'Taking you back to where you left off...'
              : "Let's start learning! 🚀",
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ).animate(delay: 400.ms).fadeIn(duration: 300.ms),
        const SizedBox(height: AppSpacing.xl),
        const LinearProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppColors.coral),
          backgroundColor: AppColors.border,
        ).animate(delay: 600.ms).fadeIn(duration: 300.ms),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final JoinError state;
  const _ErrorView({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('😕', style: TextStyle(fontSize: 64))
            .animate()
            .scale(duration: 500.ms, curve: Curves.elasticOut),
        const SizedBox(height: AppSpacing.xl),
        Text('Oops!',
                style:
                    AppTextStyles.headingLarge.copyWith(color: AppColors.coral),
                textAlign: TextAlign.center)
            .animate(delay: 100.ms)
            .fadeIn(duration: 300.ms),
        const SizedBox(height: AppSpacing.md),
        Text(state.message,
                style: AppTextStyles.bodyMedium, textAlign: TextAlign.center)
            .animate(delay: 200.ms)
            .fadeIn(duration: 300.ms),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          height: AppSizes.minTouchTarget,
          child: ElevatedButton(
            onPressed: () => context.go(AppRoutes.phoneLogin),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            child: const Text('Go to Login'),
          ),
        ).animate(delay: 300.ms).fadeIn(duration: 300.ms),
      ],
    );
  }
}
