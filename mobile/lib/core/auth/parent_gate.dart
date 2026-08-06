import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Stands between a child and the parts of the app meant for a grown-up.
///
/// The child's screens and the parent's screens share one device and, most
/// of the time, one unsupervised session. Logging out and the parent
/// dashboard were both one tap from the child's own page — a four-year-old
/// exploring could sign themselves out of an app they cannot sign back
/// into, since signing in needs a phone number.
///
/// The question is deliberately a multiplication rather than a PIN. A PIN
/// is one more thing for a parent to lose, and a child who watches it typed
/// once knows it forever. Two single digits multiplied is beyond this app's
/// entire age range and needs nothing remembered. It is a speed bump, not a
/// lock, and is not meant to survive a determined ten-year-old.
class ParentGate {
  /// Shows the gate. Resolves true only if the answer was right.
  ///
  /// Always await it before navigating; a dismissed dialog returns false.
  static Future<bool> open(BuildContext context) async {
    final passed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ParentGateDialog(),
    );
    return passed ?? false;
  }
}

class _ParentGateDialog extends StatefulWidget {
  const _ParentGateDialog();

  @override
  State<_ParentGateDialog> createState() => _ParentGateDialogState();
}

class _ParentGateDialogState extends State<_ParentGateDialog> {
  final _controller = TextEditingController();
  final _random = math.Random();
  late int _left;
  late int _right;
  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    _newQuestion();
  }

  /// Factors from 3 upward: a child who has learnt to count can sometimes
  /// reason out a two or a one, and nothing here should be answerable by
  /// counting.
  void _newQuestion() {
    _left = 3 + _random.nextInt(7);
    _right = 3 + _random.nextInt(7);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (int.tryParse(_controller.text.trim()) == _left * _right) {
      Navigator.pop(context, true);
      return;
    }
    // A fresh question rather than another go at the same one, so repeated
    // guessing does not converge.
    setState(() {
      _wrong = true;
      _newQuestion();
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      title: const Text('For grown-ups'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ask a grown-up to answer this.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '$_left × $_right = ?',
            style: AppTextStyles.headingMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              errorText: _wrong ? 'Not quite — here is another one.' : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
