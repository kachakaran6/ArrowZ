import 'package:arrowtapout/features/game/thread_animator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Exit Motion Function p(u) Mathematical Properties (Spec 13)', () {
    const double testCell = 24.0;
    const double testRay = 4.0 * testCell;
    const double testLength = 3.0 * testCell;
    const double testD = testRay + testLength + 0.6 * testCell;
    const double testA = 0.16 * testCell;

    double p(double u) => calculateExitDisplacement(
          u: u,
          totalDistanceD: testD,
          anticipationA: testA,
        );

    test('p(0) = 0 exactly', () {
      expect(p(0.0), closeTo(0.0, 1e-9));
    });

    test('p(1) = D exactly', () {
      expect(p(1.0), closeTo(testD, 1e-9));
    });

    test('p reaches negative anticipation dip (p(0.08) < 0 and p(0.1) < 0)', () {
      expect(p(0.08), lessThan(0.0));
      expect(p(0.10), lessThan(0.0));
      expect(p(0.08), closeTo(-testA, testA * 0.35));
    });

    test('p is non-increasing on [0, 0.08] (anticipation dip towards trough)', () {
      var prev = p(0.0);
      const steps = 80;
      for (var i = 1; i <= steps; i++) {
        final u = (i / steps) * 0.08;
        final curr = p(u);
        expect(curr, lessThanOrEqualTo(prev + 1e-6),
            reason: 'p($u)=$curr should be <= previous=$prev during anticipation');
        prev = curr;
      }
    });

    test('p is non-decreasing on [0.1, 1.0] (smooth acceleration out of lattice)', () {
      var prev = p(0.10);
      const steps = 900;
      for (var i = 1; i <= steps; i++) {
        final u = 0.10 + (i / steps) * 0.90;
        final curr = p(u);
        expect(curr, greaterThanOrEqualTo(prev - 1e-6),
            reason: 'p($u)=$curr should be >= previous=$prev during slide');
        prev = curr;
      }
    });

    test('finite-difference slope has no jump larger than 5% of D between consecutive 1/240 steps', () {
      const dt = 1.0 / 240.0;
      const maxAllowedJump = 0.05 * testD;

      double slopeAt(double u) {
        return (p(u + dt) - p(u)) / dt;
      }

      var prevSlope = slopeAt(0.0);
      for (var u = dt; u <= 1.0 - dt * 2; u += dt) {
        final currSlope = slopeAt(u);
        final changeInStep = (currSlope - prevSlope).abs() * dt;
        expect(changeInStep, lessThanOrEqualTo(maxAllowedJump),
            reason:
                'Slope change at u=$u is too large ($changeInStep > $maxAllowedJump)');
        prevSlope = currSlope;
      }
    });
  });
}
