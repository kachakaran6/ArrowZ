import 'dart:math';

/// Parametric mask generator for puzzle canvas shapes.
///
/// Normal levels  -> square / longRectangle
/// Boss levels    -> animal / object shapes (cat, dog, frog, fox, tiger, panda, fish, bird, butterfly, guitar, tree, house, crown, saturn)
/// God levels     -> dramatic geometric shapes (heart, star, diamond, hexagon, blob, circle)
///
/// All shapes are generated from pure math — no external images or assets.
/// Takes bounding box size and returns a Set<Cell> (and Set<String> for string keys).
class MaskGenerator {
  MaskGenerator._();

  static const List<String> bossShapeNames = [
    'cat',
    'dog',
    'frog',
    'fox',
    'tiger',
    'panda',
    'fish',
    'bird',
    'butterfly',
    'guitar',
    'tree',
    'house',
    'crown',
    'saturn',
  ];

  static const List<String> godShapeNames = [
    'heart',
    'star',
    'diamond',
    'hexagon',
    'blob',
    'circle',
  ];

  static Set<String> squareMask(int side) {
    final mask = <String>{};
    for (var r = 0; r < side; r++) {
      for (var c = 0; c < side; c++) {
        mask.add('$r,$c');
      }
    }
    return mask;
  }

  static Set<String> rectMask(int rows, int cols) {
    final mask = <String>{};
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        mask.add('$r,$c');
      }
    }
    return mask;
  }

  static Set<String> shapeByName(String name, int side, [Random? rng]) {
    switch (name) {
      case 'square':
        return squareMask(side);
      case 'longRectangle':
        final cols = (side * 0.75).round().clamp(6, side);
        return rectMask(side, cols);
      case 'circle':
        return circleMask(side);
      case 'heart':
        return heartMask(side);
      case 'star':
        return starMask(side);
      case 'diamond':
        return diamondMask(side);
      case 'hexagon':
        return hexagonMask(side);
      case 'blob':
        return blobMask(side, rng ?? Random(side));
      case 'cat':
        return catMask(side);
      case 'dog':
        return dogMask(side);
      case 'frog':
        return frogMask(side);
      case 'fox':
        return foxMask(side);
      case 'tiger':
        return tigerMask(side);
      case 'panda':
        return pandaMask(side);
      case 'fish':
        return fishMask(side);
      case 'bird':
        return birdMask(side);
      case 'butterfly':
        return butterflyMask(side);
      case 'guitar':
        return guitarMask(side);
      case 'tree':
        return treeMask(side);
      case 'house':
        return houseMask(side);
      case 'crown':
        return crownMask(side);
      case 'saturn':
        return saturnMask(side);
      default:
        return squareMask(side);
    }
  }

  // ── Circle ────────────────────────────────────────────────────────────────
  static Set<String> circleMask(int side) {
    final mask = <String>{};
    final center = (side - 1) / 2.0;
    final r2 = pow(center * 0.95, 2);
    for (var r = 0; r < side; r++) {
      for (var c = 0; c < side; c++) {
        final d2 = pow(r - center, 2) + pow(c - center, 2);
        if (d2 <= r2) mask.add('$r,$c');
      }
    }
    return mask.isNotEmpty ? mask : squareMask(side);
  }

  // ── Heart ─────────────────────────────────────────────────────────────────
  static Set<String> heartMask(int side) {
    final mask = <String>{};
    for (var r = 0; r < side; r++) {
      for (var c = 0; c < side; c++) {
        // Normalized coordinates in [-1.3, 1.3]
        final x = (c - side / 2.0) / (side / 2.5);
        final y = -(r - side * 0.45) / (side / 2.5);
        final term1 = x * x + y * y - 1;
        if (term1 * term1 * term1 - x * x * y * y * y <= 0.05) {
          mask.add('$r,$c');
        }
      }
    }
    return mask.isNotEmpty ? mask : squareMask(side);
  }

  // ── Star ──────────────────────────────────────────────────────────────────
  static Set<String> starMask(int side) {
    final mask = <String>{};
    final cx = (side - 1) / 2.0;
    final cy = (side - 1) / 2.0;
    final rOuter = side * 0.48;
    final rInner = side * 0.22;

    for (var r = 0; r < side; r++) {
      for (var c = 0; c < side; c++) {
        final dx = c - cx;
        final dy = r - cy;
        final dist = sqrt(dx * dx + dy * dy);
        var angle = atan2(dy, dx) + pi / 2;
        if (angle < 0) angle += 2 * pi;

        // 5-point star modulation
        final sector = (angle % (2 * pi / 5)) / (2 * pi / 5);
        final threshold = sector < 0.5
            ? rInner + (rOuter - rInner) * (1 - sector * 2)
            : rInner + (rOuter - rInner) * ((sector - 0.5) * 2);

        if (dist <= threshold) mask.add('$r,$c');
      }
    }
    return mask.isNotEmpty ? mask : squareMask(side);
  }

  // ── Diamond ───────────────────────────────────────────────────────────────
  static Set<String> diamondMask(int side) {
    final mask = <String>{};
    final mid = (side - 1) / 2.0;
    final maxDist = mid * 0.95;
    for (var r = 0; r < side; r++) {
      for (var c = 0; c < side; c++) {
        final dist = (r - mid).abs() + (c - mid).abs();
        if (dist <= maxDist) mask.add('$r,$c');
      }
    }
    return mask.isNotEmpty ? mask : squareMask(side);
  }

  // ── Hexagon ───────────────────────────────────────────────────────────────
  static Set<String> hexagonMask(int side) {
    final mask = <String>{};
    final cx = (side - 1) / 2.0;
    final cy = (side - 1) / 2.0;
    final rad = side * 0.46;
    for (var r = 0; r < side; r++) {
      for (var c = 0; c < side; c++) {
        final dx = (c - cx).abs();
        final dy = (r - cy).abs();
        if (dx <= rad && dy <= rad * 0.866 && (dx * 0.5 + dy * 0.866) <= rad) {
          mask.add('$r,$c');
        }
      }
    }
    return mask.isNotEmpty ? mask : squareMask(side);
  }

  // ── Blob ──────────────────────────────────────────────────────────────────
  static Set<String> blobMask(int side, Random rng) {
    final mask = <String>{};
    final cx = (side - 1) / 2.0;
    final cy = (side - 1) / 2.0;
    final rBase = side * 0.38;

    for (var r = 0; r < side; r++) {
      for (var c = 0; c < side; c++) {
        final dx = c - cx;
        final dy = r - cy;
        final dist = sqrt(dx * dx + dy * dy);
        final angle = atan2(dy, dx);
        final modulation =
            sin(angle * 3) * (side * 0.06) + cos(angle * 2) * (side * 0.04);
        if (dist <= rBase + modulation) mask.add('$r,$c');
      }
    }
    return mask.isNotEmpty ? mask : squareMask(side);
  }

  // ── Cat ───────────────────────────────────────────────────────────────────
  static Set<String> catMask(int side) {
    final mask = <String>{};
    final cx = (side - 1) / 2.0;
    final headCy = side * 0.48;
    final headR = side * 0.36;

    for (var r = 0; r < side; r++) {
      for (var c = 0; c < side; c++) {
        // Head circle
        final distHead = sqrt(pow(c - cx, 2) + pow(r - headCy, 2));
        if (distHead <= headR) {
          mask.add('$r,$c');
          continue;
        }

        // Left ear triangle
        final leftEarR = r <= side * 0.30;
        final leftEarC = c >= side * 0.15 && c <= side * 0.38;
        if (leftEarR &&
            leftEarC &&
            (r + (c - side * 0.25).abs() <= side * 0.30)) {
          mask.add('$r,$c');
          continue;
        }

        // Right ear triangle
        final rightEarR = r <= side * 0.30;
        final rightEarC = c >= side * 0.62 && c <= side * 0.85;
        if (rightEarR &&
            rightEarC &&
            (r + (c - side * 0.75).abs() <= side * 0.30)) {
          mask.add('$r,$c');
          continue;
        }
      }
    }
    return mask.isNotEmpty ? mask : squareMask(side);
  }

  // ── Dog ───────────────────────────────────────────────────────────────────
  static Set<String> dogMask(int side) {
    final mask = <String>{};
    final cx = (side - 1) / 2.0;
    final headCy = side * 0.45;
    final headR = side * 0.34;

    for (var r = 0; r < side; r++) {
      for (var c = 0; c < side; c++) {
        final distHead = sqrt(pow(c - cx, 2) + pow(r - headCy, 2));
        if (distHead <= headR) {
          mask.add('$r,$c');
          continue;
        }
        // Floppy ears on the sides
        final inLeftEar = (c >= side * 0.08 && c <= side * 0.28) &&
            (r >= side * 0.25 && r <= side * 0.70);
        final inRightEar = (c >= side * 0.72 && c <= side * 0.92) &&
            (r >= side * 0.25 && r <= side * 0.70);
        if (inLeftEar || inRightEar) {
          mask.add('$r,$c');
        }
      }
    }
    return mask.isNotEmpty ? mask : squareMask(side);
  }

  // ── Frog ──────────────────────────────────────────────────────────────────
  static Set<String> frogMask(int side) {
    final mask = <String>{};
    final cx = (side - 1) / 2.0;
    final cy = side * 0.55;
    final bodyRx = side * 0.44;
    final bodyRy = side * 0.35;

    for (var r = 0; r < side; r++) {
      for (var c = 0; c < side; c++) {
        // Body ellipse
        final inBody =
            pow((c - cx) / bodyRx, 2) + pow((r - cy) / bodyRy, 2) <= 1.0;
        if (inBody) {
          mask.add('$r,$c');
          continue;
        }
        // Left eye circle
        final dLeftEye =
            sqrt(pow(c - side * 0.26, 2) + pow(r - side * 0.24, 2));
        if (dLeftEye <= side * 0.16) {
          mask.add('$r,$c');
          continue;
        }
        // Right eye circle
        final dRightEye =
            sqrt(pow(c - side * 0.74, 2) + pow(r - side * 0.24, 2));
        if (dRightEye <= side * 0.16) {
          mask.add('$r,$c');
          continue;
        }
      }
    }
    return mask.isNotEmpty ? mask : squareMask(side);
  }

  // ── Fox ───────────────────────────────────────────────────────────────────
  static Set<String> foxMask(int side) {
    final mask = <String>{};
    final cx = (side - 1) / 2.0;
    for (var r = 0; r < side; r++) {
      for (var c = 0; c < side; c++) {
        // Snout triangle pointing down
        final snoutW = (side - r) * 0.55;
        if (r >= side * 0.35 && (c - cx).abs() <= snoutW) {
          mask.add('$r,$c');
          continue;
        }
        // Pointy ears
        if (r < side * 0.40) {
          if ((c >= side * 0.12 && c <= side * 0.38) &&
              (r >= (c - side * 0.25).abs() * 1.5)) {
            mask.add('$r,$c');
          } else if ((c >= side * 0.62 && c <= side * 0.88) &&
              (r >= (c - side * 0.75).abs() * 1.5)) {
            mask.add('$r,$c');
          }
        }
      }
    }
    return mask.isNotEmpty ? mask : squareMask(side);
  }

  // ── Tiger ─────────────────────────────────────────────────────────────────
  static Set<String> tigerMask(int side) => catMask(side);

  // ── Panda ─────────────────────────────────────────────────────────────────
  static Set<String> pandaMask(int side) {
    final mask = <String>{};
    final cx = (side - 1) / 2.0;
    final cy = side * 0.52;
    final rHead = side * 0.38;

    for (var r = 0; r < side; r++) {
      for (var c = 0; c < side; c++) {
        if (sqrt(pow(c - cx, 2) + pow(r - cy, 2)) <= rHead) {
          mask.add('$r,$c');
          continue;
        }
        // Round panda ears
        if (sqrt(pow(c - side * 0.20, 2) + pow(r - side * 0.20, 2)) <=
            side * 0.15) {
          mask.add('$r,$c');
        } else if (sqrt(pow(c - side * 0.80, 2) + pow(r - side * 0.20, 2)) <=
            side * 0.15) {
          mask.add('$r,$c');
        }
      }
    }
    return mask.isNotEmpty ? mask : squareMask(side);
  }

  // ── Fish ──────────────────────────────────────────────────────────────────
  static Set<String> fishMask(int side) {
    final mask = <String>{};
    final cy = (side - 1) / 2.0;
    for (var r = 0; r < side; r++) {
      for (var c = 0; c < side; c++) {
        // Body ellipse in left 70%
        final bx = side * 0.38;
        final rx = side * 0.34;
        final ry = side * 0.28;
        if (pow((c - bx) / rx, 2) + pow((r - cy) / ry, 2) <= 1.0) {
          mask.add('$r,$c');
          continue;
        }
        // Tail fin in right 30%
        if (c >= side * 0.65 && c <= side * 0.95) {
          final maxDy = (c - side * 0.65) * 0.9;
          if ((r - cy).abs() <= maxDy) mask.add('$r,$c');
        }
      }
    }
    return mask.isNotEmpty ? mask : squareMask(side);
  }

  // ── Bird ──────────────────────────────────────────────────────────────────
  static Set<String> birdMask(int side) {
    final mask = <String>{};
    final cx = (side - 1) / 2.0;
    final cy = (side - 1) / 2.0;
    for (var r = 0; r < side; r++) {
      for (var c = 0; c < side; c++) {
        // Body
        if (sqrt(pow(c - cx, 2) + pow(r - cy, 2)) <= side * 0.26) {
          mask.add('$r,$c');
          continue;
        }
        // Spread wings
        final wingW = (cy - r).abs();
        if (r <= cy && (c - cx).abs() <= side * 0.46 && wingW >= side * 0.05) {
          mask.add('$r,$c');
        }
      }
    }
    return mask.isNotEmpty ? mask : squareMask(side);
  }

  // ── Butterfly ─────────────────────────────────────────────────────────────
  static Set<String> butterflyMask(int side) {
    final mask = <String>{};
    final cx = (side - 1) / 2.0;
    final cy = (side - 1) / 2.0;
    for (var r = 0; r < side; r++) {
      for (var c = 0; c < side; c++) {
        // Center body line
        if ((c - cx).abs() <= 1 && r >= side * 0.15 && r <= side * 0.85) {
          mask.add('$r,$c');
          continue;
        }
        // Upper wings
        if (r <= cy) {
          final dLeft = sqrt(pow(c - side * 0.26, 2) + pow(r - side * 0.32, 2));
          final dRight =
              sqrt(pow(c - side * 0.74, 2) + pow(r - side * 0.32, 2));
          if (dLeft <= side * 0.24 || dRight <= side * 0.24) mask.add('$r,$c');
        } else {
          // Lower wings
          final dLeft = sqrt(pow(c - side * 0.30, 2) + pow(r - side * 0.68, 2));
          final dRight =
              sqrt(pow(c - side * 0.70, 2) + pow(r - side * 0.68, 2));
          if (dLeft <= side * 0.20 || dRight <= side * 0.20) mask.add('$r,$c');
        }
      }
    }
    return mask.isNotEmpty ? mask : squareMask(side);
  }

  // ── Guitar ────────────────────────────────────────────────────────────────
  static Set<String> guitarMask(int side) {
    final mask = <String>{};
    final cx = (side - 1) / 2.0;
    for (var r = 0; r < side; r++) {
      for (var c = 0; c < side; c++) {
        // Neck
        if (r <= side * 0.45 && (c - cx).abs() <= max(1, side * 0.06)) {
          mask.add('$r,$c');
          continue;
        }
        // Upper body
        if (sqrt(pow(c - cx, 2) + pow(r - side * 0.58, 2)) <= side * 0.22) {
          mask.add('$r,$c');
          continue;
        }
        // Lower body
        if (sqrt(pow(c - cx, 2) + pow(r - side * 0.78, 2)) <= side * 0.32) {
          mask.add('$r,$c');
          continue;
        }
      }
    }
    return mask.isNotEmpty ? mask : squareMask(side);
  }

  // ── Tree ──────────────────────────────────────────────────────────────────
  static Set<String> treeMask(int side) {
    final mask = <String>{};
    final cx = (side - 1) / 2.0;
    for (var r = 0; r < side; r++) {
      for (var c = 0; c < side; c++) {
        // Trunk
        if (r >= side * 0.65 && (c - cx).abs() <= max(1, side * 0.08)) {
          mask.add('$r,$c');
          continue;
        }
        // Foliage triangle
        if (r < side * 0.68) {
          final maxW = (r / (side * 0.68)) * (side * 0.44);
          if ((c - cx).abs() <= maxW) mask.add('$r,$c');
        }
      }
    }
    return mask.isNotEmpty ? mask : squareMask(side);
  }

  // ── House ─────────────────────────────────────────────────────────────────
  static Set<String> houseMask(int side) {
    final mask = <String>{};
    final cx = (side - 1) / 2.0;
    for (var r = 0; r < side; r++) {
      for (var c = 0; c < side; c++) {
        // Roof triangle
        if (r <= side * 0.45) {
          final maxW = (r / (side * 0.45)) * (side * 0.45);
          if ((c - cx).abs() <= maxW) mask.add('$r,$c');
        } else if (r <= side * 0.90) {
          // Walls square
          if ((c - cx).abs() <= side * 0.40) mask.add('$r,$c');
        }
      }
    }
    return mask.isNotEmpty ? mask : squareMask(side);
  }

  // ── Crown ─────────────────────────────────────────────────────────────────
  static Set<String> crownMask(int side) {
    final mask = <String>{};
    final cx = (side - 1) / 2.0;
    for (var r = 0; r < side; r++) {
      for (var c = 0; c < side; c++) {
        if (r >= side * 0.30 &&
            r <= side * 0.85 &&
            (c - cx).abs() <= side * 0.44) {
          // Peaks: left peak, center peak, right peak
          if (r >= side * 0.55) {
            mask.add('$r,$c');
          } else {
            final nearLeft = (c - side * 0.18).abs() <= side * 0.10;
            final nearMid = (c - cx).abs() <= side * 0.12;
            final nearRight = (c - side * 0.82).abs() <= side * 0.10;
            if (nearLeft || nearMid || nearRight) mask.add('$r,$c');
          }
        }
      }
    }
    return mask.isNotEmpty ? mask : squareMask(side);
  }

  // ── Saturn ────────────────────────────────────────────────────────────────
  static Set<String> saturnMask(int side) {
    final mask = <String>{};
    final cx = (side - 1) / 2.0;
    final cy = (side - 1) / 2.0;
    final planetR = side * 0.28;

    for (var r = 0; r < side; r++) {
      for (var c = 0; c < side; c++) {
        // Planet body
        if (sqrt(pow(c - cx, 2) + pow(r - cy, 2)) <= planetR) {
          mask.add('$r,$c');
          continue;
        }
        // Ring ellipse
        final inRing = pow((c - cx) / (side * 0.48), 2) +
                pow((r - cy) / (side * 0.12), 2) <=
            1.0;
        final insideRing = pow((c - cx) / (side * 0.34), 2) +
                pow((r - cy) / (side * 0.08), 2) <
            1.0;
        if (inRing && !insideRing) {
          mask.add('$r,$c');
        }
      }
    }
    return mask.isNotEmpty ? mask : squareMask(side);
  }
}
