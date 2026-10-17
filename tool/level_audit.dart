// ignore_for_file: avoid_print, prefer_const_declarations, prefer_final_locals
import 'dart:convert';
import 'dart:io';
import 'package:arrowtapout/data/level_binary_codec.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/engine/solvability_engine.dart';

void main(List<String> args) async {
  final sw = Stopwatch()..start();

  var startLevel = 1;
  var endLevel = 500;
  var specificLevel = -1;
  var jsonOutPath = 'reports/campaign_audit_report.json';
  var mdOutPath = 'reports/campaign_audit_report.md';

  for (final arg in args) {
    if (arg.startsWith('--level=')) {
      specificLevel = int.tryParse(arg.substring('--level='.length)) ?? -1;
    } else if (arg.startsWith('--start=')) {
      startLevel = int.tryParse(arg.substring('--start='.length)) ?? 1;
    } else if (arg.startsWith('--end=')) {
      endLevel = int.tryParse(arg.substring('--end='.length)) ?? 500;
    } else if (arg.startsWith('--range=')) {
      final parts = arg.substring('--range='.length).split('-');
      if (parts.length == 2) {
        startLevel = int.tryParse(parts[0]) ?? 1;
        endLevel = int.tryParse(parts[1]) ?? 500;
      }
    } else if (arg.startsWith('--out=')) {
      mdOutPath = arg.substring('--out='.length);
    }
  }

  if (specificLevel > 0) {
    startLevel = specificLevel;
    endLevel = specificLevel;
  }

  print('================================================================');
  print(' ARROWZ — MASTER CAMPAIGN SOLVABILITY ENGINE & AUDIT RUNNER');
  print('================================================================');
  print('Auditing levels $startLevel to $endLevel...');

  final binaryFile = File('assets/levels.bin');
  if (!binaryFile.existsSync()) {
    print('ERROR: assets/levels.bin not found!');
    exit(1);
  }

  final bytes = binaryFile.readAsBytesSync();
  final decoder = LevelBinaryDecoder.fromBytes(bytes);
  final engine = const SolvabilityEngine();

  final results = <SolvabilityReport>[];
  var passedCount = 0;
  var failedCount = 0;
  var requiresDeflectorCount = 0;
  final failedReports = <SolvabilityReport>[];

  for (var lvl = startLevel; lvl <= endLevel; lvl++) {
    final Level? level;
    try {
      level = decoder.decodeLevelByNumber(lvl);
    } catch (e) {
      print('Level $lvl: FAILED TO DECODE - $e');
      failedCount++;
      continue;
    }

    if (level == null) {
      print('Level $lvl: NOT FOUND IN REGISTRY');
      continue;
    }

    final report = engine.auditLevel(level);
    results.add(report);

    if (report.isPassed) {
      passedCount++;
      if (report.requiresDeflectors) {
        requiresDeflectorCount++;
      }
    } else {
      failedCount++;
      failedReports.add(report);
      print(
          '[-] Level ${report.levelId} (Ch. ${report.chapter}): FAILED [${report.status.name}] — ${report.failureReason}');
    }

    if (lvl % 50 == 0 || lvl == endLevel) {
      final pct = ((lvl - startLevel + 1) / (endLevel - startLevel + 1) * 100)
          .toStringAsFixed(1);
      print(
          '  [$pct%] Processed level $lvl / $endLevel | Passed: $passedCount | Failed: $failedCount');
    }
  }

  sw.stop();
  final totalDurationMs = sw.elapsedMilliseconds;

  print('\n================================================================');
  print(' AUDIT SUMMARY');
  print('================================================================');
  print('Total levels tested:         ${results.length}');
  print('Passed:                      $passedCount');
  print('Failed:                      $failedCount');
  print('Levels requiring deflectors: $requiresDeflectorCount');
  print(
      'Total duration:              ${(totalDurationMs / 1000).toStringAsFixed(2)}s');

  // Ensure reports directory exists
  Directory('reports').createSync(recursive: true);

  // Write JSON report
  final jsonReport = {
    'auditTimestamp': DateTime.now().toIso8601String(),
    'startLevel': startLevel,
    'endLevel': endLevel,
    'totalLevels': results.length,
    'passed': passedCount,
    'failed': failedCount,
    'requiresDeflectorCount': requiresDeflectorCount,
    'durationMs': totalDurationMs,
    'levels': results.map((r) => r.toJson()).toList(),
  };
  File(jsonOutPath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(jsonReport));
  print('Saved JSON report to $jsonOutPath');

  // Write Markdown report
  final mdBuffer = StringBuffer()
    ..writeln('# ARROWZ — MASTER CAMPAIGN SOLVABILITY AUDIT REPORT')
    ..writeln()
    ..writeln('**Audit Date:** ${DateTime.now().toIso8601String()}  ')
    ..writeln('**Scope:** Levels $startLevel to $endLevel  ')
    ..writeln('**Total Tested:** ${results.length}  ')
    ..writeln(
        '**Passed:** $passedCount (${(passedCount / (results.isEmpty ? 1 : results.length) * 100).toStringAsFixed(1)}%)  ')
    ..writeln('**Failed:** $failedCount  ')
    ..writeln('**Levels Requiring Deflectors:** $requiresDeflectorCount  ')
    ..writeln('**Duration:** ${(totalDurationMs / 1000).toStringAsFixed(2)}s  ')
    ..writeln()
    ..writeln('---')
    ..writeln()
    ..writeln('## Executive Summary')
    ..writeln()
    ..writeln('| Metric | Value |')
    ..writeln('|---|---|')
    ..writeln('| Total Registered Levels | 500 |')
    ..writeln('| Levels Audited in Run | ${results.length} |')
    ..writeln('| Solvable & Verified | $passedCount |')
    ..writeln('| Deadlocked / Failed | $failedCount |')
    ..writeln('| Deflector-Dependent Levels | $requiresDeflectorCount |')
    ..writeln()
    ..writeln('---')
    ..writeln();

  if (failedReports.isNotEmpty) {
    mdBuffer
      ..writeln('## Failed Levels Details')
      ..writeln()
      ..writeln(
          '| Level | Chapter | Status | Arrows | Deflectors | Failure Reason |')
      ..writeln('|---|---|---|---|---|---|');
    for (final f in failedReports) {
      mdBuffer.writeln(
          '| ${f.levelId} | ${f.chapter} | `${f.status.name}` | ${f.threadCount} | ${f.deflectorCount} | ${f.failureReason} |');
    }
    mdBuffer.writeln();
  }

  mdBuffer
    ..writeln('## Verified Campaign Sample (First 25 Levels)')
    ..writeln()
    ..writeln(
        '| Level | Ch | Status | Arrows | Deflectors | Initial Free | Solution Moves | Solv Time (ms) | Requires Deflector |')
    ..writeln('|---|---|---|---|---|---|---|---|---|');

  for (final r in results.take(25)) {
    mdBuffer.writeln(
      '| ${r.levelId} | ${r.chapter} | ${r.isPassed ? '✅ PASS' : '❌ FAIL'} | ${r.threadCount} | ${r.deflectorCount} | ${r.initialFreeCount} | ${r.solutionPath.length} | ${r.durationMs.toStringAsFixed(2)} | ${r.requiresDeflectors ? 'YES' : 'NO'} |',
    );
  }

  File(mdOutPath).writeAsStringSync(mdBuffer.toString());
  print('Saved Markdown report to $mdOutPath');

  if (failedCount > 0) {
    print(
        '\n[AUDIT FAILED]: $failedCount levels failed solvability/verification!');
    exit(2);
  } else {
    print(
        '\n[AUDIT PASSED]: All ${results.length} levels solved and verified!');
  }
}
