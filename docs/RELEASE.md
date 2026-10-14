# Release & Publishing Guide

## Version Tracking
- Current Version: `1.0.0+1` (Version code: 1, Version name: 1.0.0)

## Play Console Checklist
- [x] Application name set to **ArrowZ** (`com.arrowz.app`)
- [x] Portrait orientation locked in AndroidManifest.xml and code
- [x] Material 3 base with 5 hand-tuned themes and WCAG AAA/AA compliant contrast
- [x] 100% offline gameplay with 200 solvable levels across 10 chapters
- [x] Offline sound effects and bundled Newsreader / Manrope SIL OFL fonts
- [x] In-app update API configured with Play bottom sheet and rate limiting
- [x] In-app review API configured with milestone thresholds [8, 30, 70, 130]
- [x] Data Safety questionnaire: No data collected, no data shared
- [ ] Upload keystore generated and configured in `android/key.properties` (gitignored)
- [ ] Build release app bundle: `flutter build appbundle --release --obfuscate --split-debug-info=build/symbols`
- [ ] Upload `.aab` to Play Console internal test track
