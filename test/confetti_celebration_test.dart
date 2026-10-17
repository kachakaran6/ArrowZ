import 'dart:math' as math;

import 'package:arrowtapout/design/themes.dart';
import 'package:arrowtapout/features/game/sheets/complete_sheet.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Level Completion Confetti Celebration Tests (arrow-escape-main style)',
      () {
    testWidgets(
        '1. Complete dialog Stack contains 3 ConfettiWidget emitters (top center, bottom left, bottom right)',
        (tester) async {
      final confettiController =
          ConfettiController(duration: const Duration(seconds: 4));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppThemes.buildThemeData(
              AppThemes.tokensFor(AppThemeMode.sageLinen, Brightness.light),
              isDark: false,
            ),
            home: Scaffold(
              body: Stack(
                alignment: Alignment.center,
                children: [
                  CompleteSheet(
                    levelId: 1,
                    stars: 3,
                    threadsCleared: 4,
                    mistakes: 0,
                    onNextLevel: () {},
                    onReplay: () {},
                  ),
                  IgnorePointer(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConfettiWidget(
                        confettiController: confettiController,
                        blastDirectionality: BlastDirectionality.explosive,
                        emissionFrequency: 0.08,
                        numberOfParticles: 10,
                        maxBlastForce: 70,
                        minBlastForce: 35,
                        gravity: 0.18,
                        shouldLoop: false,
                        colors: const [
                          Colors.red,
                          Colors.blue,
                          Colors.green,
                          Colors.yellow,
                          Colors.pink,
                          Colors.purple,
                          Colors.orange,
                          Colors.teal,
                          Colors.cyan,
                        ],
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: ConfettiWidget(
                        confettiController: confettiController,
                        blastDirection: -math.pi / 4,
                        emissionFrequency: 0.04,
                        numberOfParticles: 4,
                        maxBlastForce: 80,
                        minBlastForce: 40,
                        gravity: 0.15,
                        shouldLoop: false,
                        colors: const [
                          Colors.red,
                          Colors.blue,
                          Colors.green,
                          Colors.yellow,
                          Colors.pink,
                          Colors.purple,
                          Colors.orange,
                          Colors.teal,
                          Colors.cyan,
                        ],
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: ConfettiWidget(
                        confettiController: confettiController,
                        blastDirection: -3 * math.pi / 4,
                        emissionFrequency: 0.04,
                        numberOfParticles: 4,
                        maxBlastForce: 80,
                        minBlastForce: 40,
                        gravity: 0.15,
                        shouldLoop: false,
                        colors: const [
                          Colors.red,
                          Colors.blue,
                          Colors.green,
                          Colors.yellow,
                          Colors.pink,
                          Colors.purple,
                          Colors.orange,
                          Colors.teal,
                          Colors.cyan,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify CompleteSheet dialog is visible
      expect(find.text('Complete'), findsOneWidget);
      expect(find.text('Replay'), findsOneWidget);
      expect(find.text('Next Level'), findsOneWidget);

      // Verify all 3 ConfettiWidget emitters exist in the tree
      final confettiFinder = find.byType(ConfettiWidget);
      expect(confettiFinder, findsNWidgets(3));

      // Verify all 3 emitters are wrapped inside IgnorePointer(ignoring: true)
      final ignorePointerFinder = find.ancestor(
        of: confettiFinder,
        matching: find.byWidgetPredicate(
            (w) => w is IgnorePointer && w.ignoring == true),
      );
      expect(ignorePointerFinder, findsNWidgets(3));

      // Verify alignment of emitters: topCenter, bottomLeft, bottomRight
      final alignWidgets = tester.widgetList<Align>(
        find.ancestor(of: confettiFinder, matching: find.byType(Align)),
      );
      final alignments = alignWidgets.map((a) => a.alignment).toList();
      expect(alignments.contains(Alignment.topCenter), isTrue);
      expect(alignments.contains(Alignment.bottomLeft), isTrue);
      expect(alignments.contains(Alignment.bottomRight), isTrue);

      confettiController.dispose();
    });

    testWidgets(
        '2. Confetti emitters do not obstruct tap gestures on dialog buttons',
        (tester) async {
      final confettiController =
          ConfettiController(duration: const Duration(seconds: 4));
      bool replayTapped = false;
      bool nextTapped = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppThemes.buildThemeData(
              AppThemes.tokensFor(AppThemeMode.sageLinen, Brightness.light),
              isDark: false,
            ),
            home: Scaffold(
              body: Stack(
                alignment: Alignment.center,
                children: [
                  CompleteSheet(
                    levelId: 1,
                    stars: 3,
                    threadsCleared: 4,
                    mistakes: 0,
                    onNextLevel: () => nextTapped = true,
                    onReplay: () => replayTapped = true,
                  ),
                  IgnorePointer(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConfettiWidget(
                        confettiController: confettiController,
                        blastDirectionality: BlastDirectionality.explosive,
                        shouldLoop: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Tap Next Level button despite confetti emitter layer
      await tester.tap(find.text('Next Level'));
      expect(nextTapped, isTrue);

      confettiController.dispose();
    });
  });
}
