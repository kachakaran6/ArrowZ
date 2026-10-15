import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/widgets/arrowz_wordmark.dart';
import 'package:arrowtapout/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    // Splash runs under 900 ms total, wordmark Z draws in 500ms
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _glowAnimation = CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeOut,
    );

    _glowController.forward();

    // Transition to Home after 750 ms
    Future.delayed(const Duration(milliseconds: 750), () {
      if (mounted) {
        context.go(Routes.home);
      }
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.bg,
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Soft stage light fade-in behind wordmark
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, _) {
                return Opacity(
                  opacity: _glowAnimation.value * 0.12,
                  child: Container(
                    width: 260.0,
                    height: 260.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          tokens.accent,
                          tokens.accent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // Signature ArrowZ Wordmark
            const ArrowZWordmark(
              fontSize: 48.0,
              animateOnLaunch: true,
              showTagline: true,
            ),
          ],
        ),
      ),
    );
  }
}
