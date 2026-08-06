import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/network/dio_message.dart';

// ── Model ──────────────────────────────────────────────────────────
class InviteLinkModel {
  final int id;
  final String childName;
  final String? label;
  final int useCount;
  final String expiresAt;
  final String? lastUsedAt;

  const InviteLinkModel({
    required this.id,
    required this.childName,
    required this.useCount,
    required this.expiresAt,
    this.label,
    this.lastUsedAt,
  });

  factory InviteLinkModel.fromJson(Map<String, dynamic> j) => InviteLinkModel(
        id: (j['id'] as num).toInt(),
        childName: j['child_name'] as String,
        label: j['label'] as String?,
        useCount: (j['use_count'] as num).toInt(),
        expiresAt: j['expires_at'] as String,
        lastUsedAt: j['last_used_at'] as String?,
      );
}

class ChildModel {
  final int id;
  final String name;
  const ChildModel({required this.id, required this.name});
  factory ChildModel.fromJson(Map<String, dynamic> j) => ChildModel(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String? ?? j['child_name'] as String? ?? '',
      );
}

// ── State ──────────────────────────────────────────────────────────
abstract class InviteLinksState extends Equatable {
  const InviteLinksState();
  @override
  List<Object?> get props => [];
}

class InviteLinksLoading extends InviteLinksState {
  const InviteLinksLoading();
}

class InviteLinksLoaded extends InviteLinksState {
  final List<InviteLinkModel> links;
  final List<ChildModel> children;
  final String? generatedLink;
  final String? generatedChildName;
  const InviteLinksLoaded({
    required this.links,
    required this.children,
    this.generatedLink,
    this.generatedChildName,
  });
  @override
  List<Object?> get props =>
      [links, children, generatedLink, generatedChildName];
}

class InviteLinksError extends InviteLinksState {
  final String message;
  const InviteLinksError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── Cubit ──────────────────────────────────────────────────────────
class InviteLinksCubit extends Cubit<InviteLinksState> {
  final Dio _dio;

  InviteLinksCubit(this._dio) : super(const InviteLinksLoading());

  factory InviteLinksCubit.create() => InviteLinksCubit(getIt<Dio>());

  Future<void> load() async {
    emit(const InviteLinksLoading());
    try {
      final results = await Future.wait([
        _dio.get(ApiConstants.listInviteLinks),
        _dio.get(ApiConstants.parentChildren),
      ]);

      final links = (results[0].data as List<dynamic>)
          .map((e) => InviteLinkModel.fromJson(e as Map<String, dynamic>))
          .toList();

      final children = (results[1].data as List<dynamic>)
          .map((e) => ChildModel.fromJson(e as Map<String, dynamic>))
          .toList();

      emit(InviteLinksLoaded(links: links, children: children));
    } on DioException catch (e) {
      emit(InviteLinksError(
          describeDioError(e, whileDoing: 'the invite links')));
    }
  }

  Future<void> generate({
    required int childId,
    String? label,
    int expireDays = 7,
  }) async {
    final current = state;
    try {
      final response = await _dio.post(
        ApiConstants.generateInviteLink,
        data: {
          'child_id': childId,
          if (label != null) 'label': label,
          'expires_days': expireDays,
        },
      );

      final deepLink = response.data['deep_link'] as String;
      final childName = response.data['child_name'] as String;

      // Reload links list then show the generated link
      await load();
      if (state is InviteLinksLoaded) {
        final loaded = state as InviteLinksLoaded;
        emit(InviteLinksLoaded(
          links: loaded.links,
          children: loaded.children,
          generatedLink: deepLink,
          generatedChildName: childName,
        ));
      }
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'];
      emit(InviteLinksError(detail?.toString() ?? 'Could not generate link'));
      await Future.delayed(const Duration(seconds: 2));
      if (current is InviteLinksLoaded) emit(current);
    }
  }

  Future<void> revoke(int linkId) async {
    try {
      await _dio.delete(ApiConstants.revokeInviteLink(linkId));
      await load();
    } catch (_) {
      await load();
    }
  }
}

// ── Screen ─────────────────────────────────────────────────────────
class InviteLinksScreen extends StatelessWidget {
  const InviteLinksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InviteLinksCubit.create()..load(),
      child: const _InviteLinksView(),
    );
  }
}

class _InviteLinksView extends StatelessWidget {
  const _InviteLinksView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text('Invite Links', style: AppTextStyles.headingSmall),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary),
            onPressed: () => context.read<InviteLinksCubit>().load(),
          ),
        ],
      ),
      body: BlocBuilder<InviteLinksCubit, InviteLinksState>(
        builder: (context, state) {
          if (state is InviteLinksLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.teal),
              ),
            );
          }
          if (state is InviteLinksError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('😅', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: AppSpacing.md),
                  Text(state.message, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: () => context.read<InviteLinksCubit>().load(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (state is InviteLinksLoaded) {
            return _LoadedView(state: state);
          }
          return const SizedBox();
        },
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  final InviteLinksLoaded state;
  const _LoadedView({required this.state});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // ── How it works ──────────────────────────────────────
        _HowItWorksCard(),
        const SizedBox(height: AppSpacing.lg),

        // ── Generated link (if just generated) ───────────────
        if (state.generatedLink != null) ...[
          _GeneratedLinkCard(
            link: state.generatedLink!,
            childName: state.generatedChildName ?? '',
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),
          const SizedBox(height: AppSpacing.lg),
        ],

        // ── Generate new link ─────────────────────────────────
        _GenerateLinkSection(children: state.children),
        const SizedBox(height: AppSpacing.xl),

        // ── Active links ──────────────────────────────────────
        Text('Active Links', style: AppTextStyles.headingSmall),
        const SizedBox(height: AppSpacing.md),

        if (state.links.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Column(
                children: [
                  const Text('🔗', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No active links yet.\nGenerate one above to share with your child\'s device.',
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ...state.links.asMap().entries.map(
                (e) => _LinkCard(
                  link: e.value,
                  onRevoke: () =>
                      context.read<InviteLinksCubit>().revoke(e.value.id),
                )
                    .animate(delay: Duration(milliseconds: e.key * 80))
                    .fadeIn(duration: 300.ms),
              ),

        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

// ── How it works card ──────────────────────────────────────────────
class _HowItWorksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.teal.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.teal.withOpacity(0.25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('💡', style: TextStyle(fontSize: 18)),
            const SizedBox(width: AppSpacing.sm),
            Text('How it works',
                style:
                    AppTextStyles.headingSmall.copyWith(color: AppColors.teal)),
          ]),
          const SizedBox(height: AppSpacing.md),
          _Step(n: '1', text: 'Generate a link for your child below'),
          _Step(n: '2', text: 'Share it via WhatsApp or SMS'),
          _Step(
              n: '3',
              text: "Your child taps it — they're logged in automatically"),
          _Step(
              n: '4',
              text: 'They continue learning exactly where they stopped'),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String n;
  final String text;
  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.teal,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(n,
                  style: AppTextStyles.label
                      .copyWith(color: Colors.white, fontSize: 11)),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}

// ── Generate link section ──────────────────────────────────────────
class _GenerateLinkSection extends StatefulWidget {
  final List<ChildModel> children;
  const _GenerateLinkSection({required this.children});

  @override
  State<_GenerateLinkSection> createState() => _GenerateLinkSectionState();
}

class _GenerateLinkSectionState extends State<_GenerateLinkSection> {
  ChildModel? _selectedChild;
  int _expireDays = 7;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    if (widget.children.isNotEmpty) {
      _selectedChild = widget.children.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) {
      return const SizedBox.shrink();
    }

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
          Text('Generate a New Link', style: AppTextStyles.headingSmall),
          const SizedBox(height: AppSpacing.lg),

          // Child selector
          if (widget.children.length > 1) ...[
            Text('For which child?', style: AppTextStyles.label),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<ChildModel>(
              value: _selectedChild,
              items: widget.children
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.name),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedChild = v),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Expiry
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Link expires in', style: AppTextStyles.label),
              Text('$_expireDays days',
                  style: AppTextStyles.label.copyWith(color: AppColors.teal)),
            ],
          ),
          Slider(
            value: _expireDays.toDouble(),
            min: 1,
            max: 30,
            divisions: 29,
            activeColor: AppColors.teal,
            inactiveColor: AppColors.teal.withOpacity(0.2),
            onChanged: (v) => setState(() => _expireDays = v.toInt()),
          ),

          const SizedBox(height: AppSpacing.md),

          SizedBox(
            width: double.infinity,
            height: AppSizes.minTouchTarget,
            child: ElevatedButton.icon(
              onPressed: (_selectedChild == null || _isGenerating)
                  ? null
                  : () async {
                      setState(() => _isGenerating = true);
                      await context.read<InviteLinksCubit>().generate(
                            childId: _selectedChild!.id,
                            expireDays: _expireDays,
                          );
                      if (mounted) setState(() => _isGenerating = false);
                    },
              icon: _isGenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.link_rounded),
              label: Text(_isGenerating ? 'Generating...' : 'Generate Link'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coral,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Generated link card (shown after generation) ───────────────────
class _GeneratedLinkCard extends StatelessWidget {
  final String link;
  final String childName;
  const _GeneratedLinkCard({required this.link, required this.childName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.green.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('✅', style: TextStyle(fontSize: 18)),
            const SizedBox(width: AppSpacing.sm),
            Text("$childName's invite link is ready!",
                style: AppTextStyles.headingSmall
                    .copyWith(color: AppColors.green)),
          ]),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(link,
                style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: link));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Link copied!'),
                      backgroundColor: AppColors.teal,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.teal,
                  side: const BorderSide(color: AppColors.teal),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // share_plus: Share.share(link);
                  // Until package is added, copy to clipboard
                  Clipboard.setData(ClipboardData(text: link));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Link copied! Paste it in WhatsApp or SMS.'),
                      backgroundColor: AppColors.teal,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Share'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Active link card ────────────────────────────────────────────────
class _LinkCard extends StatelessWidget {
  final InviteLinkModel link;
  final VoidCallback onRevoke;
  const _LinkCard({required this.link, required this.onRevoke});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.teal.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.link_rounded, color: AppColors.teal, size: 22),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(link.label ?? link.childName,
                    style: AppTextStyles.bodyLarge),
                Text(
                  link.lastUsedAt != null
                      ? 'Used ${link.useCount}× · last used'
                      : 'Not yet used',
                  style: AppTextStyles.bodySmall,
                ),
                Text(
                  'Expires: ${link.expiresAt.substring(0, 10)}',
                  style: AppTextStyles.bodySmall
                      .copyWith(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.coral, size: 20),
            tooltip: 'Revoke link',
            onPressed: () => _showRevokeDialog(context),
          ),
        ],
      ),
    );
  }

  void _showRevokeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: const Text('Revoke link?'),
        content: Text(
            "The child's device will no longer be able to use this link. "
            "You can generate a new one at any time.",
            style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onRevoke();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
            child: const Text('Revoke', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
