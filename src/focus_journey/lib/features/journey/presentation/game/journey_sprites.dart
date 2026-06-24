/// Presentation layer (Flame). Loads and holds the scene's sprites with
/// graceful missing-asset degradation (AC-14/TC-014). A path that is absent
/// from the bundle (or that faults while decoding) yields a neutral placeholder
/// and the scene keeps running — loading never throws, crashes, or blanks.
///
/// Loads ONLY paths from [JourneyAssets.all] (AC-11). `flutter_bloc`, the
/// engine, and OS APIs are never imported here. The only Flutter surface used
/// is the asset bundle / manifest (`package:flutter/services.dart`) — needed to
/// know which curated files actually shipped — and `dart:ui` for [Image]; the
/// separation invariant (no Bloc / engine / OS-signal imports) is preserved.
///
/// WHY THE MANIFEST PRE-CHECK (the B-1 fix): Flame 1.35.1's [Images.load] wraps
/// each asset in an internal `_ImageAsset.future` whose constructor registers a
/// `_future!.then((image){...})` listener with NO `onError`
/// (`package:flame/src/cache/images.dart`). For a genuinely-missing path
/// (e.g. `vehicles/ship.png`) the underlying `bundle.load` rejects; the caller's
/// `await` catches the rejection for control flow, but that orphan internal
/// listener has no error handler, so the rejection escapes to the zone's
/// uncaught-error handler. In the real app (no `runZonedGuarded`/global handler)
/// that surfaces as a spurious async "Unable to load asset" error on every
/// launch. By consulting the asset manifest first and calling [Images.load] ONLY
/// for paths that actually exist, we never create the orphan future for the
/// missing path — the error is eliminated at the source, not swallowed.
library;

import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flutter/services.dart'
    show AssetBundle, AssetManifest, rootBundle;

import 'journey_assets.dart';
import 'side_object_pool.dart';

/// Resolves a sprite path to its loaded [Image], or `null` if it failed (the
/// renderer then draws a procedural placeholder). Tracks failures so a test
/// seam can assert graceful degradation.
class JourneySprites {
  /// Creates a sprite store backed by Flame's [Images] cache.
  ///
  /// [bundle] is the asset bundle used for the existence pre-check; it defaults
  /// to [rootBundle] (the real app bundle) and is injectable for tests. It
  /// should be the same bundle Flame's [Images] cache reads from.
  JourneySprites(
    this._images, {
    AssetBundle? bundle,
    String assetPrefix = JourneyAssets.assetPrefix,
  }) : _bundle = bundle ?? rootBundle,
       _assetPrefix = assetPrefix;

  final Images _images;
  final AssetBundle _bundle;
  final String _assetPrefix;
  final Map<String, Image> _byPath = <String, Image>{};
  final Set<String> _failedPaths = <String>{};

  /// Paths that failed to load and are being rendered as placeholders. Test
  /// seam for TC-014. Empty when all curated assets loaded cleanly.
  Set<String> get failedPaths => Set<String>.unmodifiable(_failedPaths);

  /// Whether any asset is currently being shown as a placeholder. Test seam.
  bool get hasPlaceholders => _failedPaths.isNotEmpty;

  /// The loaded image for [path], or `null` if it failed (→ draw placeholder).
  Image? imageFor(String path) => _byPath[path];

  /// The image for a side-object [kind], or `null` if it failed.
  Image? imageForKind(SideObjectKind kind) => imageFor(_kindPath(kind));

  /// Loads every manifest asset, degrading gracefully on failure. Always
  /// completes (never rethrows) so scene startup cannot be blocked by a
  /// missing file. Idempotent.
  ///
  /// Paths absent from the asset bundle are recorded as failed (placeholder)
  /// WITHOUT calling [Images.load] — see the library doc for why this avoids
  /// Flame's orphan-rejected-future leak (the B-1 fix).
  Future<void> loadAll() async {
    final Set<String> available = await _availablePaths();
    for (final String path in JourneyAssets.all) {
      if (available.contains(path)) {
        await _tryLoad(path);
      } else {
        // Absent from the bundle: degrade to placeholder. We never touch
        // _images.load(path), so no orphan rejected future is created.
        _byPath.remove(path);
        _failedPaths.add(path);
      }
    }
  }

  /// The set of manifest paths (relative to [_assetPrefix]) that actually ship
  /// in the bundle. If the manifest itself cannot be read, returns empty so
  /// every asset degrades to a placeholder rather than throwing.
  Future<Set<String>> _availablePaths() async {
    try {
      final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(
        _bundle,
      );
      final List<String> assets = manifest.listAssets();
      final Set<String> relative = <String>{};
      for (final String full in assets) {
        if (full.startsWith(_assetPrefix)) {
          relative.add(full.substring(_assetPrefix.length));
        }
      }
      return relative;
    } on Object {
      return const <String>{};
    }
  }

  Future<void> _tryLoad(String path) async {
    try {
      final Image img = await _images.load(path);
      _byPath[path] = img;
      _failedPaths.remove(path);
    } on Object {
      // AC-14: degrade, do not propagate. Record for the placeholder + seam.
      // (Reached only if a present-in-manifest asset faults while decoding.)
      _failedPaths.add(path);
    }
  }

  static String _kindPath(SideObjectKind kind) {
    switch (kind) {
      case SideObjectKind.tree:
        return JourneyAssets.tree;
      case SideObjectKind.house:
        return JourneyAssets.house;
      case SideObjectKind.streetLight:
        return JourneyAssets.streetLight;
      case SideObjectKind.sign:
        return JourneyAssets.sign;
    }
  }
}
