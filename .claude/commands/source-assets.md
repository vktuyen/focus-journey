---
description: Browse the web for FREE, license-clean UI/game art matching a described need, present options with licence + attribution, then download, optimise, and register the chosen assets under assets/ (+ assets/CREDITS.md). Invoked during Phase 3 (Build) by /implement; can also be run on its own.
argument-hint: <what art you need, e.g. "motorbike sprite + roadside trees, cozy 2D">
---

Source free, license-clean assets for: $ARGUMENTS

Delegate to `ui-asset-curator`. It will:
1. Search CC0 / permissive sources (Kenney, OpenGameArt [CC0], unDraw, Google Fonts, Lottie community, SVGRepo).
2. Present 2–4 options with: preview/description, **licence**, author, and source URL — and wait for the user to choose.
3. On approval: download, optimise, place under `assets/<category>/`, append a row to `assets/CREDITS.md` (`file · source · author · licence · attribution`), and register the path in `pubspec.yaml`.

Rule: never import an asset whose licence is unclear or whose terms conflict with the use. If nothing fits, say so rather than shipping a risky asset.
