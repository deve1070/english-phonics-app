import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/auth/biometric_auth_service.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/token_storage.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/screen_time/screen_time_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';

/// A "Parent" button in the home screen AppBar, beside a fingerprint icon.
///
/// When tapped:
///   1. Fingerprint/face prompt appears
///   2. On success → saves child token, swaps to parent JWT → opens dashboard
///
/// Invisible if no biometric token is stored on this device
/// (child-only devices set up via invite link).
class ParentDashboardButton extends StatefulWidget {
  const ParentDashboardButton({super.key});

  @override
  State<ParentDashboardButton> createState() => _ParentDashboardButtonState();
}

class _ParentDashboardButtonState extends State<ParentDashboardButton> {
  bool _isAuthenticating = false;
  bool _canUseBiometrics = false;

  late final TokenStorage _tokenStorage;
  late final BiometricAuthService _biometricService;

  @override
  void initState() {
    super.initState();
    _tokenStorage = getIt<TokenStorage>();
    _biometricService = BiometricAuthService(getIt(), _tokenStorage);
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final can = await _biometricService.canUseBiometrics();
    if (mounted) setState(() => _canUseBiometrics = can);
  }

  Future<void> _openParentDashboard() async {
    if (_isAuthenticating) return;
    setState(() => _isAuthenticating = true);

    try {
      // Attempt biometric — returns parent JWT or null
      final parentToken = await _biometricService.authenticateParent();

      if (parentToken == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric authentication failed. Try again.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Stop counting screen time before swapping tokens: the child has
      // left the learning view. Runs while the child's own token is still
      // the active one, and the parent JWT returned above is already
      // stashed, so either credential can authorize the call.
      await getIt<ScreenTimeService>().endSession();

      // Preserve child token so we can restore it when parent exits
      final childToken = await _tokenStorage.getAccessToken();
      if (childToken != null && childToken.isNotEmpty) {
        await _tokenStorage.saveChildToken(childToken);
      }

      // Swap to parent token
      await _tokenStorage.saveTokens(
        accessToken: parentToken,
      );
      await _tokenStorage.saveParentAccessToken(parentToken);
      await _tokenStorage.saveUserRole('PARENT');

      if (mounted) context.push(AppRoutes.parentDashboard);
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show if a biometric token is stored on this device
    return FutureBuilder<String?>(
      future: _tokenStorage.getBiometricToken(),
      builder: (context, snapshot) {
        // No biometric token → this is a child-only device → hide button
        if (!snapshot.hasData || (snapshot.data?.isEmpty ?? true)) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: _openParentDashboard,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs + 2,
              ),
              decoration: BoxDecoration(
                color: _isAuthenticating
                    ? AppColors.border
                    : AppColors.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(
                  color: AppColors.teal.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isAuthenticating)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.teal),
                      ),
                    )
                  else
                    Icon(
                      _canUseBiometrics
                          ? Icons.fingerprint_rounded
                          : Icons.supervisor_account_rounded,
                      color: AppColors.teal,
                      size: 16,
                    ),
                  const SizedBox(width: 4),
                  Text(
                    'Parent',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.teal,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
