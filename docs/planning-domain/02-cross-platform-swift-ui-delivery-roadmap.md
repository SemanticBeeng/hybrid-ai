# 02 Cross-Platform Swift UI Delivery Roadmap

## Purpose

This document captures the execution-oriented roadmap for proving and then expanding the cross-platform Swift UI strategy.

## Delivery Sequence

### Stage 1: Shared Core Validation

1. Keep `HybridAI` as the shared Swift package.
2. Move shared app state and reusable abstractions into the package.
3. Preserve CLI targets as smoke coverage for the shared core.

### Stage 2: Linux UI Proof

1. Add or evolve a Linux GTK/libadwaita shell.
2. Keep the Linux shell mobile-shaped by default.
3. Validate that Linux UI work depends on the shared Swift core rather than duplicating state logic.

### Stage 3: Apple Shell Preparation

1. Add macOS app project(s) on macOS that import the shared Swift package.
2. Prepare the path for iOS shell work using the same shared package.
3. Keep platform views thin and app logic centralized.

### Stage 4: Cross-Platform App Model Maturity

1. Expand shared app/view model abstractions.
2. Reuse those abstractions from Linux and Apple shells.
3. Validate that conversation and runtime flows remain portable.

## Immediate Proof Options

1. Linux-first proof
   - build a small GTK/libadwaita shell that imports `HybridAI`
   - keep the window phone-sized and interaction model touch-friendly

2. Apple-first proof
   - build a small macOS SwiftUI app importing the same package

3. Cross-platform abstraction proof
   - implement `AppModel` or `ViewModel` in shared Swift first
   - reuse later from GTK and SwiftUI shells

## Verification Expectations

1. Linux: Swift build/test plus Linux UI build/run proof
2. macOS: shared package tests plus macOS shell build
3. iOS: future Xcode/device build once Apple-side shell work begins

## Current Planning Preference

The preferred planning path remains:
1. shared Swift core first
2. Linux UI proof second
3. Apple shell expansion after the shared core is proven reusable

## Source Runbooks

- `docs/chat/swift_ui_cross_platform_roadmap.md`