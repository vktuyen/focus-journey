# `lib/` layout — Clean Architecture + Bloc + DI

This package follows **Clean Architecture** with three layers per feature, **SOLID**, and
**dependency injection** (nothing is `new`-ed inside widgets/blocs). Stack & rationale:
[`docs/architecture/overview.md`](../../../docs/architecture/overview.md), ADR-0002.

```
lib/
  core/                 # cross-feature primitives (errors, DI, base classes, constants)
  features/
    <feature>/
      domain/           # pure Dart: entities, value objects, repository/plugin INTERFACES.
                        #   No Flutter, no platform channels, no I/O. The contract.
      data/             # implementations of domain interfaces: platform channels,
                        #   native backends, mocks, repositories, persistence.
      presentation/     # Bloc/Cubit + widgets. Depends on domain, never on data directly.
```

## Rules

- **Dependencies point inward.** `presentation` → `domain` ← `data`. `domain` depends on
  nothing Flutter-specific. Concrete `data` types are wired to `presentation` via injection
  (constructor params / a DI seam in `core/`), never imported into widgets.
- **Bloc:** UI reads state from Blocs/Cubits; Blocs receive their dependencies (domain
  interfaces) by constructor. No `BlocProvider` should construct an infrastructure object.
- **Testability:** because the boundary is an interface, every feature is unit-testable with a
  mock implementation and no real timers / no real OS / no real I/O.

## First feature: `activity`

`features/activity/` implements the `ActivityPlugin` slice — the domain interface
(`getSystemIdleSeconds()`, `isScreenLocked()`), its macOS/Windows platform-channel backends,
and a deterministic mock source. See [`specs/activity-detection/`](../../../specs/activity-detection/).
