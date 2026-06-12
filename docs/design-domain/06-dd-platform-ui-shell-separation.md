# 06 DD Platform UI Shell Separation

## Scope

This document captures the design boundary between the shared Swift core and platform-specific UI shells.

## Design Statement

Platform shells should remain thin presentation layers over the shared Swift core.

## Intended Shell Mapping

1. Linux shell
   - GTK or libadwaita presentation
   - mobile-form-factor approximation

2. Apple shell
   - SwiftUI, UIKit, or AppKit presentation as appropriate
   - native Apple deployment path

## Shared Core Responsibilities

- domain types
- app model and conversation state
- runtime abstractions
- service integration logic

## Shell Responsibilities

- render conversation state
- collect user input
- show loading, streaming, and error states
- avoid direct ownership of transport or engine behavior

## Design Constraint

The repository should not assume one literal UI toolkit will compile unchanged across Linux and Apple targets.

## Source Runbooks

- [[swift_ui_cross_platform_roadmap]]