// Deterministic unit tests for the pure compact-window clamp math.
//
// Scope: AC-6 (fixed compact size) + AC-8 (off-screen / invalid saved position
// clamped back onto a visible display; sensible default corner when missing).
// Pure math — no real display, no screen_retriever, no OS window.
// Mock-path companion to TC-019-POS / TC-019-CLAMP (tests/cases/mini-window.md).

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/mini_window/domain/compact_geometry.dart';
import 'package:focus_journey/features/mini_window/domain/window_position.dart';

void main() {
  // A single 1440x900 primary display with a 24px menu-bar inset at top.
  const primary = VisibleDisplay(left: 0, top: 24, width: 1440, height: 876);

  group('CompactGeometry.clampOntoVisible', () {
    test('onScreen_desiredFullyInside_returnsDesiredUnchanged', () {
      const desired = WindowPosition(x: 200, y: 200);
      final result = CompactGeometry.clampOntoVisible(
        desired: desired,
        displays: const <VisibleDisplay>[primary],
      );
      expect(result, desired);
    });

    test('offScreen_negativeCoords_clampedBackOntoDisplay', () {
      const desired = WindowPosition(x: -500, y: -500);
      final result = CompactGeometry.clampOntoVisible(
        desired: desired,
        displays: const <VisibleDisplay>[primary],
      );
      // Clamped to the display's top-left origin (left, top).
      expect(result.x, primary.left);
      expect(result.y, primary.top);
    });

    test('offScreen_beyondRightBottom_clampedSoWholeWindowVisible', () {
      const desired = WindowPosition(x: 5000, y: 5000);
      final result = CompactGeometry.clampOntoVisible(
        desired: desired,
        displays: const <VisibleDisplay>[primary],
      );
      // The whole fixed-size window stays inside: x+width <= right, y+height <= bottom.
      expect(
        result.x + CompactGeometry.width,
        lessThanOrEqualTo(primary.right),
      );
      expect(
        result.y + CompactGeometry.height,
        lessThanOrEqualTo(primary.bottom),
      );
    });

    test('noSavedPosition_returnsBottomRightDefaultCorner', () {
      final result = CompactGeometry.clampOntoVisible(
        desired: null,
        displays: const <VisibleDisplay>[primary],
      );
      // Near the bottom-right, fully on-screen.
      expect(result.x, greaterThan(primary.left));
      expect(
        result.x + CompactGeometry.width,
        lessThanOrEqualTo(primary.right),
      );
      expect(
        result.y + CompactGeometry.height,
        lessThanOrEqualTo(primary.bottom),
      );
    });

    test('noDisplays_returnsDesiredOrDefaultWithoutThrowing', () {
      const desired = WindowPosition(x: 10, y: 10);
      expect(
        CompactGeometry.clampOntoVisible(
          desired: desired,
          displays: const <VisibleDisplay>[],
        ),
        desired,
      );
      // Null desired + no displays still yields a usable position.
      final fallback = CompactGeometry.clampOntoVisible(
        desired: null,
        displays: const <VisibleDisplay>[],
      );
      expect(fallback.x, greaterThanOrEqualTo(0));
      expect(fallback.y, greaterThanOrEqualTo(0));
    });

    test('secondaryDisplay_positionOnSecondScreen_kept', () {
      // A second display to the right of primary.
      const secondary = VisibleDisplay(
        left: 1440,
        top: 24,
        width: 1920,
        height: 1056,
      );
      const desired = WindowPosition(x: 1600, y: 100);
      final result = CompactGeometry.clampOntoVisible(
        desired: desired,
        displays: const <VisibleDisplay>[primary, secondary],
      );
      expect(result, desired);
    });

    // --- Extended edge coverage (TC-019-CLAMP): multi-display bounds, exact
    // edges, oversized displays, and the fixed-size invariant (AC-8). ---

    // TC-019-CLAMP: a position fully inside the SECONDARY display (the primary
    // would reject it) must be kept unchanged — the clamp must consider EVERY
    // display, not just the first.
    test('multiDisplay_insideSecondaryOnly_keptUnchanged', () {
      const secondary = VisibleDisplay(
        left: -1920, // a second monitor to the LEFT of primary
        top: 0,
        width: 1920,
        height: 1080,
      );
      // Off the primary (negative x) but fully on the secondary.
      const desired = WindowPosition(x: -1800, y: 100);
      final result = CompactGeometry.clampOntoVisible(
        desired: desired,
        displays: const <VisibleDisplay>[primary, secondary],
      );
      expect(result, desired);
    });

    // TC-019-CLAMP: a saved position from an UNPLUGGED monitor (off every
    // current display) is clamped back into the first/primary display so the
    // whole fixed-size window is visible.
    test('multiDisplay_offEveryDisplay_clampedIntoFirstDisplay', () {
      const secondary = VisibleDisplay(
        left: 1440,
        top: 24,
        width: 1920,
        height: 1056,
      );
      // Far below/right of both displays (e.g. a 4th monitor was removed).
      const desired = WindowPosition(x: 9000, y: 9000);
      final result = CompactGeometry.clampOntoVisible(
        desired: desired,
        displays: const <VisibleDisplay>[primary, secondary],
      );
      // Lands fully inside the FIRST display (the clamp target).
      expect(result.x, greaterThanOrEqualTo(primary.left));
      expect(result.y, greaterThanOrEqualTo(primary.top));
      expect(result.x + CompactGeometry.width, lessThanOrEqualTo(primary.right));
      expect(
        result.y + CompactGeometry.height,
        lessThanOrEqualTo(primary.bottom),
      );
    });

    // TC-019-CLAMP / AC-8: a position EXACTLY on the bottom-right edge (the last
    // fully-visible spot) is in-bounds and must be returned unchanged.
    test('exactlyOnFarEdge_lastFullyVisibleSpot_keptUnchanged', () {
      final desired = WindowPosition(
        x: primary.right - CompactGeometry.width,
        y: primary.bottom - CompactGeometry.height,
      );
      final result = CompactGeometry.clampOntoVisible(
        desired: desired,
        displays: const <VisibleDisplay>[primary],
      );
      expect(result, desired);
    });

    // TC-019-CLAMP / AC-8: a position EXACTLY on the top-left origin is the
    // first fully-visible spot and must be kept unchanged.
    test('exactlyOnTopLeftOrigin_keptUnchanged', () {
      final desired = WindowPosition(x: primary.left, y: primary.top);
      final result = CompactGeometry.clampOntoVisible(
        desired: desired,
        displays: const <VisibleDisplay>[primary],
      );
      expect(result, desired);
    });

    // TC-019-CLAMP: a position one logical pixel PAST the far edge is out of
    // bounds and is clamped back so the window is still fully visible.
    test('onePixelPastFarEdge_clampedBackIntoView', () {
      final desired = WindowPosition(
        x: primary.right - CompactGeometry.width + 1,
        y: primary.bottom - CompactGeometry.height + 1,
      );
      final result = CompactGeometry.clampOntoVisible(
        desired: desired,
        displays: const <VisibleDisplay>[primary],
      );
      expect(result.x, primary.right - CompactGeometry.width);
      expect(result.y, primary.bottom - CompactGeometry.height);
    });

    // TC-019-CLAMP / AC-8: when the only display is SMALLER than the fixed
    // compact window, clamp must not place it off the top-left; it pins to the
    // display origin (graceful — window can't be fully shown but is anchored).
    test('displaySmallerThanWindow_pinsToDisplayOrigin', () {
      const tiny = VisibleDisplay(left: 10, top: 20, width: 100, height: 100);
      const desired = WindowPosition(x: 5000, y: 5000);
      final result = CompactGeometry.clampOntoVisible(
        desired: desired,
        displays: const <VisibleDisplay>[tiny],
      );
      // maxX/maxY would be negative; the impl pins to the display origin.
      expect(result.x, tiny.left);
      expect(result.y, tiny.top);
    });

    // AC-8 fixed-size invariant: the clamp NEVER widens/narrows the window; it
    // only ever returns a position. The constant compact size is what matters.
    test('fixedSizeInvariant_widthAndHeightAreConstants', () {
      expect(CompactGeometry.width, 280);
      expect(CompactGeometry.height, 180);
    });
  });
}
