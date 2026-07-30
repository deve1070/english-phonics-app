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

  /// `POST /parents/register` takes exactly
  /// `{name, phone_number, child: {name, user_name, nickname?}}`.
  /// Auth here is fully passwordless — there is no email, no password and
  /// no age field on either the parent or the child.
  Future<void> register({
    required String parentName,
    required String parentPhone,
    required String childName,
    required String childUserName,
    String? childNickname,
  }) async {
    emit(const ParentRegisterLoading());
    try {
      final response = await _dio.post(
        ApiConstants.parentRegister,
        data: {
          'name': parentName,
          'phone_number': parentPhone,
          'child': {
            'name': childName,
            'user_name': childUserName,
            if (childNickname != null && childNickname.trim().isNotEmpty)
              'nickname': childNickname.trim(),
          },
        },
      );

      final accessToken = (response.data['access_token'] ?? '').toString();
      if (accessToken.isEmpty) {
        emit(const ParentRegisterError('Registration failed. Please try again.'));
        return;
      }
      await _tokenStorage.saveTokens(accessToken: accessToken);

      // Registration returns a parent session, so stash it under the parent
      // key too — parent-scoped calls read that even once the active token
      // has been swapped for a child's session token.
      await _tokenStorage.saveParentAccessToken(accessToken);
      await _tokenStorage.saveUserRole('PARENT');

      // Keeps "stay signed in" working on next launch. The server rotates
      // this on every use, so it must be persisted, not derived.
      final biometricToken = (response.data['biometric_token'] ?? '').toString();
      if (biometricToken.isNotEmpty) {
        await _tokenStorage.saveBiometricToken(biometricToken);
      }

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
  final _parentPhoneCtrl = TextEditingController();

  // Child controllers
  final _childNameCtrl = TextEditingController();
  final _childUserNameCtrl = TextEditingController();
  final _childNicknameCtrl = TextEditingController();

  @override
  void dispose() {
    _parentNameCtrl.dispose();
    _parentPhoneCtrl.dispose();
    _childNameCtrl.dispose();
    _childUserNameCtrl.dispose();
    _childNicknameCtrl.dispose();
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
            parentPhone: _parentPhoneCtrl.text.trim(),
            childName: _childNameCtrl.text.trim(),
            childUserName: _childUserNameCtrl.text.trim(),
            childNickname: _childNicknameCtrl.text.trim(),
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
                        phoneCtrl: _parentPhoneCtrl,
                        onNext: _next,
                      )
                    : _ChildStep(
                        key: const ValueKey('child'),
                        nameCtrl: _childNameCtrl,
                        userNameCtrl: _childUserNameCtrl,
                        nicknameCtrl: _childNicknameCtrl,
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
  final TextEditingController phoneCtrl;
  final VoidCallback onNext;

  const _ParentStep({
    super.key,
    required this.nameCtrl,
    required this.phoneCtrl,
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
        // Phone number is the whole credential — there is no password.
        _Field(
            ctrl: phoneCtrl,
            label: 'Phone number',
            icon: Icons.phone_rounded,
            isPhone: true),
        const SizedBox(height: AppSpacing.sm),
        Text(
          "This is how you'll sign in — no password to remember.",
          style: AppTextStyles.bodySmall,
        ),

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
  final TextEditingController nicknameCtrl;
  final VoidCallback onSubmit;

  const _ChildStep({
    super.key,
    required this.nameCtrl,
    required this.userNameCtrl,
    required this.nicknameCtrl,
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
          "You'll switch into their account from your dashboard.",
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
            ctrl: nicknameCtrl,
            label: 'Nickname (optional)',
            icon: Icons.favorite_rounded,
            isOptional: true),

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
  final bool isPhone;
  final bool isOptional;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.isPhone = false,
    this.isOptional = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
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
        final value = v?.trim() ?? '';
        if (value.isEmpty) {
          return isOptional ? null : 'This field is required';
        }
        if (isPhone && value.replaceAll(RegExp(r'[^0-9]'), '').length < 9) {
          return 'Enter a valid phone number';
        }
        return null;
      },
    );
  }
}
