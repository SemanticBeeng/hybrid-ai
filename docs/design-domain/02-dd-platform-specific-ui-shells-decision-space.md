# 02 DD Platform-Specific UI Shells Decision Space

## Scope

This document is the overview for the platform-shell design cluster.

## Cluster Summary

The shell design cluster covers:

1. toolkit choice and platform fit
2. separation between the shared core and shell code
3. mobile-form-factor approximation on Linux

## Detailed Documents

- [[06-dd-platform-ui-shell-separation]]

## Current Preferred Design Direction

Use a shared Swift core plus platform-specific thin UI shells.

Current preferred mapping:
- Linux: GTK/libadwaita mobile-form-factor shell
- macOS: SwiftUI or AppKit-backed shell
- iOS: SwiftUI or UIKit-backed shell

## Decision Space Kept Here

1. Option A: SwiftUI on Apple plus GTK/libadwaita on Linux
2. Option B: SwiftUI on Apple plus Qt on Linux/macOS
3. Option C: SwiftCrossUI or Tokamak-style approach
4. Option D: web UI shell plus Swift backend

## Active Design Decision

The repository currently prefers Option A:
- Apple-native UI on Apple platforms
- GTK/libadwaita-style Linux shell for Linux-hosted development and approximation
- shared Swift package for logic, app model, and service interfaces

## Source Runbooks

- [[swift_ui_cross_platform_roadmap]]