# System overview diagram

Component + data-flow picture of Vietnam Focus Journey (Clean Architecture layers).
Renders on GitHub. Keep in sync with [../overview.md](../overview.md); the prose there is authoritative.

```mermaid
flowchart TD
    subgraph OS["OS / native"]
        IDLE["System idle counters<br/>lock / sleep state"]
    end

    subgraph DATA["Data layer"]
        PLUGIN["ActivityPlugin<br/>(Swift macOS · C++ Win32 · mock)"]
        STORE["Persistence<br/>shared_preferences / JSON"]
        TILES["OSM tiles (v2)<br/>anonymous GET · offline fallback"]
    end

    subgraph DOMAIN["Domain layer (pure Dart)"]
        TICKER["Activity ticker<br/>delta = now − lastTick → active|idle|paused"]
        ENGINE["JourneyEngine.tick(delta)<br/>journey time vs raw active time<br/>distanceKm · state · mode"]
        ROUTE["Route / progress model<br/>ProvinceChain · RoutePlan (v2)"]
    end

    subgraph PRES["Presentation layer"]
        BLOC["Bloc / Cubit"]
        FLAME["Flame POV scene"]
        UI["Journey · Map · Stats screens<br/>+ mini-window PiP (v2)"]
    end

    IDLE -->|platform channel| PLUGIN
    PLUGIN --> TICKER
    TICKER --> ENGINE
    ENGINE --> ROUTE
    ENGINE --> BLOC
    ROUTE --> BLOC
    BLOC --> FLAME
    BLOC --> UI
    TILES --> UI
    ENGINE <--> STORE
    ROUTE <--> STORE
```

**Key invariants shown:** the engine is pure Dart with an injected clock + `ActivityPlugin` (deterministic,
testable); distance comes from journey time while stats come from raw active time (BR-6); the only network
egress is anonymous OSM tiles (BR-11).
