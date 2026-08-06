import 'package:flutter/material.dart';
import '../../../../core/mascot/kiki.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      mood: KikiMood.listening,
      title: 'Listen & Learn',
      subtitle: 'Tap any letter and hear how\nit sounds out loud!',
      bgColor: Color(0xFFFFEDD8),
      accentColor: AppColors.coral,
      bubbles: [
        _Bubble(emoji: 'A', color: AppColors.coral, top: 0.12, left: 0.08),
        _Bubble(emoji: 'B', color: AppColors.teal, top: 0.18, right: 0.10),
        _Bubble(emoji: '🔊', color: AppColors.yellow, bottom: 0.22, left: 0.12),
      ],
    ),
    _OnboardingPage(
      mood: KikiMood.encouraging,
      title: 'Speak It Out!',
      subtitle: 'Practice pronunciation and\nget instant feedback.',
      bgColor: Color(0xFFE8FAF8),
      accentColor: AppColors.teal,
      bubbles: [
        _Bubble(emoji: '⭐', color: AppColors.yellow, top: 0.10, right: 0.08),
        _Bubble(emoji: '🎤', color: AppColors.coral, top: 0.20, left: 0.06),
        _Bubble(emoji: '✨', color: AppColors.teal, bottom: 0.20, right: 0.10),
      ],
    ),
    _OnboardingPage(
      mood: KikiMood.celebrating,
      title: 'Earn & Celebrate',
      subtitle: 'Complete lessons, win stars,\nand become a reading champion!',
      bgColor: Color(0xFFFFFBE6),
      accentColor: AppColors.yellow,
      bubbles: [
        _Bubble(emoji: '🏆', color: AppColors.yellow, top: 0.10, left: 0.08),
        _Bubble(emoji: '⭐', color: AppColors.coral, top: 0.16, right: 0.08),
        _Bubble(emoji: '🎉', color: AppColors.teal, bottom: 0.18, left: 0.10),
      ],
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) context.go(AppRoutes.phoneLogin);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        color: page.bgColor,
        child: Stack(
          children: [
            // Decorative background blobs
            Positioned(
              top: -80,
              right: -80,
              child:
                  _Blob(color: page.accentColor.withOpacity(0.10), size: 240),
            ),
            Positioned(
              bottom: -60,
              left: -60,
              child:
                  _Blob(color: page.accentColor.withOpacity(0.08), size: 200),
            ),

            // Skip button
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 16),
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Skip',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: page.accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Page view
            PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) {
                return _PageContent(page: _pages[index]);
              },
            ),

            // Bottom controls
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Page indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == _currentPage ? 28 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _currentPage
                                  ? page.accentColor
                                  : page.accentColor.withOpacity(0.25),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // CTA button
                      SizedBox(
                        width: double.infinity,
                        height: AppSizes.minTouchTarget,
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: page.accentColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            isLast ? "Let's Start! 🚀" : 'Next',
                            style: AppTextStyles.buttonLarge,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Single page content ──────────────────────────────────────────
class _PageContent extends StatelessWidget {
  final _OnboardingPage page;
  const _PageContent({required this.page});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 60),

            // Image + floating bubbles
            Expanded(
              flex: 5,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Floating emoji bubbles
                  ...page.bubbles.map((b) => _FloatingBubble(bubble: b)),

                  // She fills whatever the page leaves her. Sized from the
                  // shorter side because she is square.
                  LayoutBuilder(
                    builder: (context, c) => Kiki(
                      size: c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight,
                      mood: page.mood,
                    ),
                  ).animate().fadeIn(duration: 400.ms).scale(
                        begin: const Offset(0.85, 0.85),
                        duration: 400.ms,
                        curve: Curves.easeOut,
                      ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              page.title,
              style: AppTextStyles.displayMedium.copyWith(
                color: page.accentColor,
              ),
              textAlign: TextAlign.center,
            )
                .animate()
                .fadeIn(duration: 350.ms, delay: 100.ms)
                .slideY(begin: 0.2, end: 0, duration: 350.ms),

            const SizedBox(height: 12),

            // Subtitle
            Text(
              page.subtitle,
              style: AppTextStyles.bodyLarge.copyWith(
                color: const Color(0xFF5A5A6A),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(duration: 350.ms, delay: 200.ms),

            // Space for bottom controls
            const SizedBox(height: 140),
          ],
        ),
      ),
    );
  }
}

// ── Floating bubble widget ────────────────────────────────────────
class _FloatingBubble extends StatefulWidget {
  final _Bubble bubble;
  const _FloatingBubble({required this.bubble});

  @override
  State<_FloatingBubble> createState() => _FloatingBubbleState();
}

class _FloatingBubbleState extends State<_FloatingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1800 + widget.bubble.hashCode % 600),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bubble;
    return Positioned(
      top: b.top != null ? MediaQuery.of(context).size.height * b.top! : null,
      bottom: b.bottom != null
          ? MediaQuery.of(context).size.height * b.bottom!
          : null,
      left: b.left != null ? MediaQuery.of(context).size.width * b.left! : null,
      right:
          b.right != null ? MediaQuery.of(context).size.width * b.right! : null,
      child: AnimatedBuilder(
        animation: _floatAnim,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, _floatAnim.value),
          child: child,
        ),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: b.color.withOpacity(0.18),
            shape: BoxShape.circle,
            border: Border.all(color: b.color.withOpacity(0.3), width: 1.5),
          ),
          child: Center(
            child: Text(b.emoji, style: const TextStyle(fontSize: 22)),
          ),
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// ── Data classes ──────────────────────────────────────────────────
class _OnboardingPage {
  final KikiMood mood;
  final String title;
  final String subtitle;
  final Color bgColor;
  final Color accentColor;
  final List<_Bubble> bubbles;

  const _OnboardingPage({
    required this.mood,
    required this.title,
    required this.subtitle,
    required this.bgColor,
    required this.accentColor,
    required this.bubbles,
  });
}

class _Bubble {
  final String emoji;
  final Color color;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;

  const _Bubble({
    required this.emoji,
    required this.color,
    this.top,
    this.bottom,
    this.left,
    this.right,
  });
}
