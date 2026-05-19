import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/network/token_storage.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';

// ── State ─────────────────────────────────────────────────────────
abstract class ParentRegisterState extends Equatable {
  const ParentRegisterState();
  @override
  List<Object?> get props => [];
}

class ParentRegisterInitial extends ParentRegisterState {
  const ParentRegisterInitial();
}

class ParentRegisterLoading extends ParentRegisterState {
  const ParentRegisterLoading();
}

class ParentRegisterSuccess extends ParentRegisterState {
  const ParentRegisterSuccess();
}

class ParentRegisterError extends ParentRegisterState {
  final String message;
  const ParentRegisterError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── Cubit ─────────────────────────────────────────────────────────
class ParentRegisterCubit extends Cubit<ParentRegisterState> {
  final Dio _dio;
  final TokenStorage _tokenStorage;

  ParentRegisterCubit(this._dio, this._tokenStorage)
      : super(const ParentRegisterInitial());

  factory ParentRegisterCubit.create() => ParentRegisterCubit(
        getIt<Dio>(),
        getIt<TokenStorage>(),
      );

  Future<void> register({
    required String parentName,
    required String parentEmail,
    required String parentPassword,
    required String childName,
    required String childUserName,
    required String childPassword,
    int? childAge,
  }) async {
    emit(const ParentRegisterLoading());
    try {
      final response = await _dio.post(
        '/parents/register',
        data: {
          'name': parentName,
          'email': parentEmail,
          'password': parentPassword,
          'child': {
            'name': childName,
            'user_name': childUserName,
            'password': childPassword,
            'age_group': childAge ?? 7,
          },
        },
      );

      await _tokenStorage.saveTokens(
        accessToken: response.data['access_token'] as String,
        refreshToken: '',
      );
      // Save role so router knows this is a parent session
      await _tokenStorage.saveSubscriptionStatus('TRIAL');

      emit(const ParentRegisterSuccess());
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'] ?? 'Registration failed';
      emit(ParentRegisterError(detail.toString()));
    } catch (e) {
      emit(ParentRegisterError(e.toString()));
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────
class ParentRegisterScreen extends StatelessWidget {
  const ParentRegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ParentRegisterCubit.create(),
      child: const _ParentRegisterView(),
    );
  }
}

class _ParentRegisterView extends StatefulWidget {
  const _ParentRegisterView();

  @override
  State<_ParentRegisterView> createState() => _ParentRegisterViewState();
}

class _ParentRegisterViewState extends State<_ParentRegisterView> {
  final _formKey = GlobalKey<FormState>();
  int _step = 0; // 0 = parent info, 1 = child info

  // Parent controllers
  final _parentNameCtrl = TextEditingController();
  final _parentEmailCtrl = TextEditingController();
  final _parentPasswordCtrl = TextEditingController();

  // Child controllers
  final _childNameCtrl = TextEditingController();
  final _childUserNameCtrl = TextEditingController();
  final _childPasswordCtrl = TextEditingController();
  int _childAge = 7;

  @override
  void dispose() {
    _parentNameCtrl.dispose();
    _parentEmailCtrl.dispose();
    _parentPasswordCtrl.dispose();
    _childNameCtrl.dispose();
    _childUserNameCtrl.dispose();
    _childPasswordCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _step = 1);
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<ParentRegisterCubit>().register(
            parentName: _parentNameCtrl.text.trim(),
            parentEmail: _parentEmailCtrl.text.trim(),
            parentPassword: _parentPasswordCtrl.text,
            childName: _childNameCtrl.text.trim(),
            childUserName: _childUserNameCtrl.text.trim(),
            childPassword: _childPasswordCtrl.text,
            childAge: _childAge,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ParentRegisterCubit, ParentRegisterState>(
      listener: (context, state) {
        if (state is ParentRegisterSuccess) {
          context.go(AppRoutes.parentDashboard);
        } else if (state is ParentRegisterError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.coral,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: _step == 1
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded),
                  onPressed: () => setState(() => _step = 0),
                )
              : null,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _step == 0
                    ? _ParentStep(
                        key: const ValueKey('parent'),
                        nameCtrl: _parentNameCtrl,
                        emailCtrl: _parentEmailCtrl,
                        passwordCtrl: _parentPasswordCtrl,
                        onNext: _next,
                      )
                    : _ChildStep(
                        key: const ValueKey('child'),
                        nameCtrl: _childNameCtrl,
                        userNameCtrl: _childUserNameCtrl,
                        passwordCtrl: _childPasswordCtrl,
                        age: _childAge,
                        onAgeChanged: (v) => setState(() => _childAge = v),
                        onSubmit: _submit,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Step 1: Parent info ───────────────────────────────────────────
class _ParentStep extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final VoidCallback onNext;

  const _ParentStep({
    super.key,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step indicator
        _StepIndicator(current: 0),
        const SizedBox(height: AppSpacing.xl),

        Text('Create Your\nParent Account',
            style:
                AppTextStyles.displayMedium.copyWith(color: AppColors.coral)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          "You'll manage your child's learning from here.",
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),

        _Field(
            ctrl: nameCtrl,
            label: 'Your full name',
            icon: Icons.person_rounded),
        const SizedBox(height: AppSpacing.md),
        _Field(
            ctrl: emailCtrl,
            label: 'Email address',
            icon: Icons.email_rounded,
            isEmail: true),
        const SizedBox(height: AppSpacing.md),
        _Field(
            ctrl: passwordCtrl,
            label: 'Create a password',
            icon: Icons.lock_rounded,
            isPassword: true),

        const SizedBox(height: AppSpacing.xl),

        SizedBox(
          width: double.infinity,
          height: AppSizes.minTouchTarget,
          child: ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            child: const Text("Next: Set Up Child's Account"),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        Center(
          child: TextButton(
            onPressed: () => context.go(AppRoutes.login),
            child: Text(
              'Already have an account? Sign in',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.coral),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 350.ms);
  }
}

// ── Step 2: Child info ────────────────────────────────────────────
class _ChildStep extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController userNameCtrl;
  final TextEditingController passwordCtrl;
  final int age;
  final ValueChanged<int> onAgeChanged;
  final VoidCallback onSubmit;

  const _ChildStep({
    super.key,
    required this.nameCtrl,
    required this.userNameCtrl,
    required this.passwordCtrl,
    required this.age,
    required this.onAgeChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepIndicator(current: 1),
        const SizedBox(height: AppSpacing.xl),

        Text("Set Up Your\nChild's Account",
            style: AppTextStyles.displayMedium.copyWith(color: AppColors.teal)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          "Your child will use this to log in and learn.",
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),

        _Field(
            ctrl: nameCtrl,
            label: "Child's full name",
            icon: Icons.child_care_rounded),
        const SizedBox(height: AppSpacing.md),
        _Field(
            ctrl: userNameCtrl,
            label: 'Username (e.g. "alex123")',
            icon: Icons.badge_rounded),
        const SizedBox(height: AppSpacing.md),
        _Field(
            ctrl: passwordCtrl,
            label: "Child's password",
            icon: Icons.lock_outline_rounded,
            isPassword: true),

        const SizedBox(height: AppSpacing.lg),

        // Age selector
        Text("Child's age", style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: List.generate(8, (i) {
            final ageVal = i + 4; // ages 4-11
            final isSelected = age == ageVal;
            return GestureDetector(
              onTap: () => onAgeChanged(ageVal),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.teal : AppColors.surfaceVariant,
                  border: Border.all(
                    color: isSelected ? AppColors.teal : AppColors.border,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    '$ageVal',
                    style: AppTextStyles.label.copyWith(
                      color:
                          isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: AppSpacing.xl),

        BlocBuilder<ParentRegisterCubit, ParentRegisterState>(
          builder: (context, state) {
            final isLoading = state is ParentRegisterLoading;
            return SizedBox(
              width: double.infinity,
              height: AppSizes.minTouchTarget,
              child: ElevatedButton(
                onPressed: isLoading ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)
                    : const Text('Create Accounts & Start Learning! 🚀'),
              ),
            );
          },
        ),
      ],
    ).animate().fadeIn(duration: 350.ms);
  }
}

// ── Shared widgets ────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(2, (i) {
        final isActive = i == current;
        final isDone = i < current;
        return Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isActive ? 32 : 12,
              height: 12,
              decoration: BoxDecoration(
                color: isDone
                    ? AppColors.green
                    : isActive
                        ? AppColors.coral
                        : AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            if (i < 1)
              Container(
                  width: 20,
                  height: 2,
                  color: AppColors.border,
                  margin: const EdgeInsets.symmetric(horizontal: 4)),
          ],
        );
      }),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool isPassword;
  final bool isEmail;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.isPassword = false,
    this.isEmail = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      obscureText: isPassword,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.coral, width: 2),
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'This field is required';
        if (isEmail && !v.contains('@')) return 'Enter a valid email';
        if (isPassword && v.length < 6)
          return 'Password must be at least 6 characters';
        return null;
      },
    );
  }
}
