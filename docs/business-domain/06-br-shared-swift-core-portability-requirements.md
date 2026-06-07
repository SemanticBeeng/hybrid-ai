# 06 BR Shared Swift Core Portability Requirements

## Intent

This document captures the requirement that reusable app logic lives in a shared Swift core rather than inside a single platform shell.

## Requirement Statements

1. Shared domain logic, app state, and service abstractions must live in a reusable Swift package.
2. Linux, macOS, and future iOS shells must be able to consume that shared core without re-owning business logic.
3. Platform-specific UI shells may differ in toolkit and presentation as long as the shared interaction model remains portable.
4. Early Linux proofs must strengthen the shared core rather than forcing platform-specific logic into the shell.

## Ubiquitous Language

- `shared Swift core`: the package that owns platform-neutral domain logic and service interfaces
- `platform shell`: a target-specific UI surface such as GTK on Linux or SwiftUI on Apple platforms
- `portable interaction model`: a conversation and runtime behavior model that remains stable across shells

## Acceptance Implications

1. Shared app-model logic should be testable without a UI shell.
2. Linux UI work should validate reuse of the shared core, not replace it.
3. Apple-side shells must be able to inherit the same runtime and conversation abstractions later.

## Source Runbooks

- [[swift_ui_cross_platform_roadmap]]
- [[litert_lm_gemma4_swift_runbook]]