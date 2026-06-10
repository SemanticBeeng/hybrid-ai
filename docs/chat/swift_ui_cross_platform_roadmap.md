# Swift UI Cross-Platform Roadmap

Date: 2026-06-04
Status: Roadmap
Scope: Build on the verified Swiftly-backed Swift baseline and plan a Swift UI application strategy for Linux, macOS, and future iOS support.

## 1. Checkpoint

The current Swift baseline builds and tests cleanly.

Verified on 2026-06-04:
- `swift` resolves to `/opt/bin/dev/swiftly/bin/swift`
- `clang` resolves to `/opt/bin/dev/swiftly/bin/clang`
- Swift version is `6.3.2`
- Swift build path is `build/swift`
- Swift tests pass with Swift `Testing`
- `scripts/env/toolchain/doctor.sh` passes

## 2. What It Takes To Build A Swift App With UI Across Linux, macOS, And Potentially iOS

Related domain docs:
- [[02-br-cross-platform-swift-ui-delivery-target]]
- [[06-br-shared-swift-core-portability-requirements]]
- [[02-dd-platform-specific-ui-shells-decision-space]]
- [[06-dd-platform-ui-shell-separation]]

### 2.1 Key Constraint

There is no single official Apple `SwiftUI` stack that builds natively on Linux.

So the practical architecture is:

| Layer | Linux | macOS | iOS |
|---|---|---|---|
| Shared app/domain logic | Swift Package | Swift Package | Swift Package |
| Shared state/view models | Swift Package | Swift Package | Swift Package |
| UI layer | GTK/libadwaita mobile-form-factor shell, Qt, or cross-platform Swift UI framework | SwiftUI/AppKit or cross-platform framework | SwiftUI/UIKit or cross-platform framework |
| Build host | Linux OK | macOS required for Apple UI | macOS + Xcode required |

Important: iOS cannot be built from Linux in the normal Apple toolchain path. iOS builds require macOS + Xcode/iOS SDK.

## 3. Best Practical Option

Related domain docs:
- [[06-br-shared-swift-core-portability-requirements]]
- [[06-dd-platform-ui-shell-separation]]
- [[06-shared-core-to-shell-delivery-sequence]]

For “best UI” across Linux and macOS, while keeping iOS possible:

### Recommended Architecture

Use shared Swift core plus platform-specific thin UI shells.

Structure:

```text
src/swift/
  Package.swift
  Sources/
    HybridAI/
      shared domain logic
      app state
      view models
      service interfaces
    HybridAICLI/
      current CLI
    HybridAILinuxApp/
      Linux mobile-form-factor UI shell
  Tests/
    HybridAITests/

apps/
  macos/
    HybridAI.xcodeproj or .xcworkspace
    SwiftUI macOS app shell
  ios/
    HybridAI.xcodeproj or .xcworkspace
    SwiftUI iOS app shell
```

This gives:
- maximum native UI quality on Apple platforms with `SwiftUI`
- a real Linux-hosted app using GTK/libadwaita or Qt, designed to look and behave like a mobile app rather than a conventional desktop utility
- shared Swift logic and tests across all platforms
- no attempt to force Linux to pretend it has Apple `SwiftUI`

## 4. UI Toolkit Choices

Related domain docs:
- [[02-dd-platform-specific-ui-shells-decision-space]]
- [[06-dd-platform-ui-shell-separation]]

### 4.1 Option 1: SwiftUI On Apple + GTK/libadwaita On Linux

Best if Linux UX matters and the prototype should visually match a mobile app.

- Linux: GTK 4 / libadwaita via Swift bindings or C interop, using an adaptive/mobile layout
- macOS/iOS: SwiftUI
- Shared: Swift package with domain logic and view models

Pros:
- best native feel per platform
- realistic Linux support
- clean iOS path
- libadwaita is designed for adaptive layouts, so a Linux window can approximate a phone-sized app shell during development

Cons:
- UI views are written twice
- need adapter layer around state/actions

### 4.2 Option 2: SwiftUI On Apple + Qt On Linux/macOS

Best if you want a strong cross-desktop UI.

- Linux/macOS: Qt/QML or Qt Widgets via bindings/interoperability
- iOS: possible in Qt world, but more complex
- Apple-native iOS still better with SwiftUI

Pros:
- mature desktop toolkit
- strong Linux/macOS support

Cons:
- Swift integration is more complex
- iOS story is not as clean as SwiftUI
- licensing/build complexity

### 4.3 Option 3: SwiftCrossUI / Tokamak-Style Declarative Swift UI

Best if you want one Swift declarative UI API.

- Provides SwiftUI-inspired cross-platform UI
- May support GTK/AppKit/UIKit-style backends depending on framework maturity

Pros:
- closest to “one Swift UI codebase”
- declarative UI style

Cons:
- less mature than SwiftUI/GTK/Qt
- may not support every platform feature
- riskier for production polish

### 4.4 Option 4: Web UI Shell + Swift Backend

Best if the app is more “dashboard/control plane” than native app.

- Swift backend/core
- Web UI frontend
- Desktop packaging via WebKit/Tauri-like wrapper or browser
- iOS via native shell or web app

Pros:
- maximum UI portability
- easiest cross-platform visual consistency

Cons:
- not a pure Swift UI app
- less native desktop/mobile feel

## 5. Recommended Path For This Repository

Related domain docs:
- [[02-cross-platform-swift-ui-delivery-roadmap]]
- [[06-shared-core-to-shell-delivery-sequence]]
- [[06-br-shared-swift-core-portability-requirements]]

Given the current setup and goals, use this path:

1. Keep `HybridAI` as the shared Swift package.
2. Add shared app state/view models to `HybridAI`.
3. Keep `HybridAICLI` as the CLI smoke target.
4. Add a Linux UI target only after choosing GTK/libadwaita or Qt; for the first proof, make it a mobile-form-factor shell, not a desktop-style app.
5. Add macOS/iOS SwiftUI app projects on macOS that import the same `HybridAI` Swift package.
6. Use CI/build matrix:
   - Linux: `scripts/modules/swift/run.sh build/test` plus Linux UI target if added
   - macOS: Swift package tests plus macOS SwiftUI app build
   - iOS: Xcode build/archive on macOS

## 6. Minimum Next Implementation Step

Related domain docs:
- [[06-shared-core-to-shell-delivery-sequence]]
- [[02-dd-platform-specific-ui-shells-decision-space]]

To prove “Swift app with UI” from this repository, the next concrete checkpoint should be one of the following.

### 6.1 Linux-First Proof

Add a small GTK/libadwaita Swift app target that imports `HybridAI` and presents a mobile-form-factor UI showing:

```text
hybrid-ai swift module ready
```

Then verify:

```text
scripts/modules/swift/ui_run.sh build --product hybrid-ai-mobile-chat
```

Design constraints for this proof:
- make the Linux window phone-sized by default
- use a single-column layout
- prefer large touch-friendly controls
- avoid desktop-first UI patterns such as menu bars, dense toolbars, sidebars, and multi-pane layouts
- structure state and actions so the same model can be reused by future SwiftUI iOS/macOS shells

### 6.2 Apple-First Proof

Add `apps/macos/HybridAI` SwiftUI app that imports the local `HybridAI` package and shows the same status string.

Then verify on macOS with Xcode:

```text
xcodebuild build
```

### 6.3 Cross-Platform Abstraction Proof

Add shared `AppModel` / `ViewModel` types in `HybridAI`, test them on Linux now, and consume them later from GTK and SwiftUI shells.

## 7. Recommendation

Related domain docs:
- [[02-cross-platform-swift-ui-delivery-roadmap]]
- [[06-shared-core-to-shell-delivery-sequence]]

Best next step: shared Swift core plus platform-specific UI shells.

That gives the best Linux/macOS UI quality and keeps the iOS path clean.
