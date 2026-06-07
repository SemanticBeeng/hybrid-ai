# 02 Platform-Specific UI Shells Decision Space

## Scope

This document captures the design options and current direction for cross-platform Swift UI delivery.

## Current Preferred Design Direction

Use a shared Swift core plus platform-specific thin UI shells.

Current preferred mapping:
- Linux: GTK/libadwaita mobile-form-factor shell
- macOS: SwiftUI or AppKit-backed shell
- iOS: SwiftUI or UIKit-backed shell

## Decision Space Considered

### Option A: SwiftUI On Apple + GTK/libadwaita On Linux

Pros:
- strongest native feel per platform
- clean separation between shared logic and platform UI
- realistic Linux mobile-form-factor approximation

Cons:
- UI views are written twice
- requires a stable shared app state and service abstraction layer

### Option B: SwiftUI On Apple + Qt On Linux/macOS

Pros:
- mature cross-desktop toolkit story
- stronger shared desktop UI options

Cons:
- more integration complexity for Swift
- less clean iOS story than Apple-native UI
- licensing/build concerns may grow faster

### Option C: SwiftCrossUI / Tokamak-Style Approach

Pros:
- closest to one declarative Swift UI API across platforms

Cons:
- maturity and completeness risk
- uncertain platform polish and feature support
- higher architectural risk for production quality

### Option D: Web UI Shell + Swift Backend

Pros:
- easiest consistency across platforms
- highest portability

Cons:
- weaker native feel
- diverges from the goal of a native Swift application experience

## Active Design Decision

The repository currently prefers Option A:
- Apple-native UI on Apple platforms
- GTK/libadwaita-style Linux shell for Linux-hosted development and approximation
- shared Swift package for logic, app model, and service interfaces

## Important Design Constraint

There is no single official Apple `SwiftUI` stack that builds natively on Linux. This makes a unified literal SwiftUI codebase across Linux and Apple targets a poor primary assumption for this repository.

## Bounded Context View

1. `Shared Core Context`
   - domain logic
   - app state
   - service interfaces

2. `Linux Shell Context`
   - GTK/libadwaita presentation
   - mobile-form-factor approximation

3. `Apple Shell Context`
   - SwiftUI/AppKit/UIKit presentation
   - native Apple deployment path

The shared core should remain the stable seam across those contexts.

## Source Runbooks

- `docs/chat/swift_ui_cross_platform_roadmap.md`