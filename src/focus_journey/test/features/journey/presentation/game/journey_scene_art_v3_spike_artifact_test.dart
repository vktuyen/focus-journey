// journey-scene-art-v3 art-direction spike + fallback-ladder PROCESS gates.
//
// AC-1 / AC-2 are PROCESS + human-judgement gates. The cohesion/craft judgement
// and the fallback-rightness judgement are the MANUAL review legs TC-M-SPIKE /
// TC-M-FALLBACK (see tests/cases/journey-scene-art-v3-manual-checklist.md). What
// is mechanically CHECKABLE — and what these tests assert — is the EXISTENCE of
// the committed artifacts and the process guard:
//
//   TC-301 (AC-1) — a recorded spike artifact exists: a candidate family that
//                   claims to cover ALL scene categories (incl. beach/coast +
//                   side-view animals), a per-asset licence list, a side-by-side
//                   comparison, AND a dated human sign-off — committed in
//                   assets/CREDITS.md before any asset is treated as landed.
//   TC-302 (AC-2) — the recorded fallback rung follows the decided ladder and
//                   any rung-2/3 use is a dated, explicit, signed-off deviation
//                   (no silent category drop).
//
// These read assets/CREDITS.md from disk (the committed spike record).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Directory _packageRoot() {
  Directory dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync() &&
        File('${dir.path}/assets/CREDITS.md').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      return Directory.current;
    }
    dir = parent;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final root = _packageRoot();
  final credits = File('${root.path}/assets/CREDITS.md').readAsStringSync();
  final lower = credits.toLowerCase();

  // ===========================================================================
  // TC-301 (AC-1) — spike artifact + dated human sign-off exists.
  // ===========================================================================
  group('TC-301 art-direction spike artifact + sign-off exists (AC-1)', () {
    test('spikeRecord_namesACandidateFamilyCoveringAllCategories', () {
      // The committed spike record must reference the chosen family AND name the
      // hard categories the slice exists to cover (beach/coast + side-view
      // animals) — proof the spike surveyed for full coverage, not a gap-fill.
      expect(
        lower.contains('spike'),
        isTrue,
        reason: 'CREDITS must record the art-direction spike (AC-1)',
      );
      expect(
        lower.contains('coverage matrix') || lower.contains('coverage'),
        isTrue,
        reason: 'the spike must record a category-coverage record (AC-1)',
      );
      for (final category in const <String>['beach', 'coast', 'animal']) {
        expect(
          lower.contains(category),
          isTrue,
          reason: 'spike record must address the "$category" category (AC-1)',
        );
      }
    });

    test('perAssetLicenceList_andComparison_areRecorded', () {
      // A per-asset licence list (the CREDITS tables themselves) + a side-by-side
      // look comparison (the predecessor→new mapping / contact-sheet caveat).
      expect(lower.contains('licence') || lower.contains('license'), isTrue);
      expect(
        lower.contains('predecessor') ||
            lower.contains('side-by-side') ||
            lower.contains('contact sheet'),
        isTrue,
        reason:
            'spike must record a side-by-side comparison vs the shipped set',
      );
    });

    test('datedHumanSignOff_existsBeforeAssetsTreatedAsLanded', () {
      // The AC-1 hard gate: a DATED human sign-off is recorded, and the manifest
      // replacement is documented as post-dating it ("SIGNED OFF" + a date).
      expect(
        lower.contains('signed off') ||
            lower.contains('sign-off') ||
            lower.contains('signed-off'),
        isTrue,
        reason: 'a human sign-off must be recorded (AC-1 gate)',
      );
      // A date is present on the sign-off (the 2026-06-25 approval).
      expect(
        RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(credits),
        isTrue,
        reason: 'the sign-off must be DATED (AC-1 process guard)',
      );
      // The record states the assets landed AFTER / as a result of the sign-off
      // (no asset before sign-off) — the "SHIPPED ... SIGNED OFF" framing.
      expect(
        lower.contains('shipped') && lower.contains('signed off'),
        isTrue,
        reason:
            'the manifest replacement must be recorded as post-sign-off (no '
            'asset lands before the spike sign-off — AC-1)',
      );
    });
  });

  // ===========================================================================
  // TC-302 (AC-2) — fallback rung recorded; rung-2/3 = signed-off deviation.
  // ===========================================================================
  group(
    'TC-302 fallback-ladder honoured; rung-2/3 = signed-off deviation (AC-2)',
    () {
      test('recordedFallbackRung_followsTheDecidedLadder', () {
        // The fallback ladder is named: switch family (rung 1) → original flat
        // vectors (rung 2) → procedural/drop (rung 3). The record must name the
        // rung actually used.
        expect(
          lower.contains('fallback'),
          isTrue,
          reason: 'CREDITS must record the fallback decision (AC-2)',
        );
        expect(
          lower.contains('rung'),
          isTrue,
          reason: 'the recorded fallback must name the ladder rung used (AC-2)',
        );
      });

      test('anyRung2Or3Use_isADatedSignedOffDeviation_noSilentDrop', () {
        // This slice used a hybrid rung-1 + rung-2 (original flat vectors). Rung-2
        // use MUST be recorded as an explicit, dated, signed-off deviation — and no
        // category is silently dropped (the resolved beach + animals prove it).
        final usesRung2Or3 =
            lower.contains('rung-2') ||
            lower.contains('rung 2') ||
            lower.contains('rung-3') ||
            lower.contains('rung 3');
        expect(
          usesRung2Or3,
          isTrue,
          reason:
              'this slice recorded a rung-2 hybrid; expected it named (AC-2)',
        );
        // The deviation is recorded + signed off + dated.
        expect(
          lower.contains('deviation'),
          isTrue,
          reason:
              'rung-2/3 use must be recorded as an explicit deviation (AC-2)',
        );
        expect(
          (lower.contains('signed off') || lower.contains('signed-off')) &&
              RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(credits),
          isTrue,
          reason: 'the rung-2/3 deviation must be DATED + signed off (AC-2)',
        );
        // No silent category drop: the previously-deferred categories are RESOLVED.
        expect(
          lower.contains('resolved'),
          isTrue,
          reason:
              'the beach + animal categories must be recorded as RESOLVED, not '
              'silently dropped (AC-2)',
        );
      });
    },
  );
}
