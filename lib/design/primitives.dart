import 'package:flutter/animation.dart';

/// Raw design primitives for Unwind.
///
/// Widgets should never consume primitives directly; use [AppTokens] instead.
abstract final class Primitives {
  // Spacing (4pt grid)
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space56 = 56.0;

  // Radii (scale 10, 16, 24, 28)
  static const double radius10 = 10.0;
  static const double radius16 = 16.0;
  static const double radius24 = 24.0;
  static const double radius28 = 28.0;

  static const double radiusChip = radius10;
  static const double radiusButton = radius16;
  static const double radiusCard = radius24;
  static const double radiusSheet = radius28;

  // Durations
  static const Duration durationInstant = Duration(milliseconds: 90);
  static const Duration durationFast = Duration(milliseconds: 160);
  static const Duration durationBase = Duration(milliseconds: 240);
  static const Duration durationPage = Duration(milliseconds: 280);
  static const Duration durationSlow = Duration(milliseconds: 360);
  static const Duration durationExitMin = Duration(milliseconds: 320);
  static const Duration durationExitMax = Duration(milliseconds: 900);

  // Curves
  static const Curve curveStandard = Curves.easeInOutCubic;
  static const Curve curveEnter = Cubic(0.16, 1.0, 0.3, 1.0);
  static const Curve curveExitIn = Cubic(0.5, 0.0, 0.9, 0.5);

  // Font family names
  static const String fontDisplay = 'Bricolage Grotesque';
  static const String fontUi = 'Figtree';

  // Palette 1: Sage Linen (light) - tuned to match ArrowZ icon
  static const Color sageBg = Color(0xFFF3F6EE);
  static const Color sageSurface = Color(0xFFFAFBF6);
  static const Color sageSurfaceRaised = Color(0xFFFFFFFF);
  static const Color sageInk = Color(0xFF16261C);
  static const Color sageInkMuted = Color(0xFF4D6151);
  static const Color sageThreadFaint = Color(0xFFC7D2C3);
  static const Color sageAccent = Color(0xFF2C4835);
  static const Color sageOnAccent = Color(0xFFF4F7EE);
  static const Color sageDanger = Color(0xFFB04D3B);
  static const Color sageSuccess = Color(0xFF386840);

  // Palette 2: Ink and Brass (dark)
  static const Color brassBg = Color(0xFF14161A);
  static const Color brassSurface = Color(0xFF1B1E23);
  static const Color brassSurfaceRaised = Color(0xFF23272D);
  static const Color brassInk = Color(0xFFECE6D8);
  static const Color brassInkMuted = Color(0xFFA59F8F);
  static const Color brassThreadFaint = Color(0xFF343840);
  static const Color brassAccent = Color(0xFFC7A15A);
  static const Color brassOnAccent = Color(0xFF14161A);
  static const Color brassDanger = Color(0xFFD0705A);
  static const Color brassSuccess = Color(0xFF8FA874);

  // Palette 3: Fog Slate (light)
  static const Color slateBg = Color(0xFFE8ECEE);
  static const Color slateSurface = Color(0xFFF2F5F6);
  static const Color slateSurfaceRaised = Color(0xFFFBFCFC);
  static const Color slateInk = Color(0xFF22303A);
  static const Color slateInkMuted = Color(0xFF50606B);
  static const Color slateThreadFaint = Color(0xFFC4CED4);
  static const Color slateAccent = Color(0xFF2B5B72);
  static const Color slateOnAccent = Color(0xFFF2F5F6);
  static const Color slateDanger = Color(0xFFB5513F);
  static const Color slateSuccess = Color(0xFF3D6E5B);

  // Palette 4: Rosewood (light)
  static const Color roseBg = Color(0xFFF1E6E0);
  static const Color roseSurface = Color(0xFFF8F0EB);
  static const Color roseSurfaceRaised = Color(0xFFFCF8F5);
  static const Color roseInk = Color(0xFF3A2626);
  static const Color roseInkMuted = Color(0xFF6E5652);
  static const Color roseThreadFaint = Color(0xFFD9C5BD);
  static const Color roseAccent = Color(0xFF7A2E44);
  static const Color roseOnAccent = Color(0xFFF8F0EB);
  static const Color roseDanger = Color(0xFFA86A14);
  static const Color roseSuccess = Color(0xFF557139);

  // Palette 5: Graphite Ember (dark)
  static const Color emberBg = Color(0xFF1A1816);
  static const Color emberSurface = Color(0xFF221F1C);
  static const Color emberSurfaceRaised = Color(0xFF2B2723);
  static const Color emberInk = Color(0xFFE9E2D6);
  static const Color emberInkMuted = Color(0xFFA89F92);
  static const Color emberThreadFaint = Color(0xFF3A3530);
  static const Color emberAccent = Color(0xFFD17B4A);
  static const Color emberOnAccent = Color(0xFF1A1816);
  static const Color emberDanger = Color(0xFFD95C4E);
  static const Color emberSuccess = Color(0xFF8FA874);
}
