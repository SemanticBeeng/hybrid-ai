# 03 BR Apple Deployment Authority

## Intent

This document isolates the deployment environments whose constraints are authoritative for product decisions.

## Requirement Statements

1. Real iPhone and iPad deployment is the authoritative product environment.
2. Product decisions about inference, storage, and runtime ownership must be judged first against iOS device constraints.
3. Mac Catalyst is allowed as an Apple-hosted approximation, but it does not replace validation on real iOS hardware.
4. Linux and desktop validation results may inform feasibility, but they do not override iOS deployment truth.

## Ubiquitous Language

- `deployment authority`: the environment whose constraints decide whether a design is acceptable
- `Apple-hosted approximation`: a development mode on Apple platforms used to rehearse the target design without claiming full equivalence to iOS hardware
- `final truth`: the behavior observed on the real target class of device

## Acceptance Implications

1. Memory, thermal, and startup assumptions must remain compatible with iPhone-class hardware.
2. Model packaging and writable-state decisions must remain compatible with app-bundle and sandbox rules.
3. Mac-side success is evidence of progress, not proof of product readiness.

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]