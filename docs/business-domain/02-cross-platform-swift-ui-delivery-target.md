# 02 Cross-Platform Swift UI Delivery Target

## Intent

This document captures the product-facing requirements implied by the current Swift UI cross-platform roadmap.

## Core Requirements

1. The project must support a shared Swift core that can be reused across Linux, macOS, and future iOS app surfaces.
2. Apple UI delivery should remain native on Apple platforms rather than forcing Linux to emulate Apple `SwiftUI` directly.
3. Linux UI delivery should still be a real app shell rather than a pure placeholder or CLI-only proof.
4. The Linux UI should be shaped as a mobile-form-factor approximation rather than a desktop-first control panel.
5. The architecture must preserve a clean path to future iOS application delivery.

## Ubiquitous Language

- `shared Swift core`: the Swift package that owns domain logic, state, and reusable service abstractions
- `thin UI shell`: a platform-specific presentation layer that depends on the shared Swift core rather than re-owning business logic
- `mobile-form-factor shell`: a UI surface intentionally constrained to phone-like interaction and layout patterns even when hosted on a desktop OS
- `platform-native UI`: a UI stack that follows the normal toolkit expectations of the target platform rather than forcing one UI toolkit across all targets

## Product Constraints

1. There is no requirement to force one literal UI toolkit across Linux and Apple platforms.
2. iOS remains a future delivery target, so design choices should not block Apple-native application development later.
3. Linux is allowed to use a different UI shell as long as the shared core and interaction model remain portable.

## Acceptance-Oriented Implications

1. Shared app state and view-model style abstractions should live in the reusable Swift package.
2. Platform-specific views should be thin enough that Linux and Apple shells can diverge visually without fragmenting app logic.
3. Early Linux proofs should validate reusable interaction patterns rather than overfitting to a desktop-only UI style.

## Source Runbooks

- `docs/chat/swift_ui_cross_platform_roadmap.md`