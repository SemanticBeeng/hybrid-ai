# Design Domain

This folder tracks design-domain knowledge extracted from runbooks and implementation work.

Purpose:
- record design decisions, alternatives, tradeoffs, and bounded contexts
- preserve inconsistent or work-in-progress design directions without forcing premature resolution
- support reasoning across alternative architectures and implementation paths

Conventions:
- one Markdown file per design concern or bounded context
- file names use a two-digit prefix and an expressive name
- examples: `01-cross-platform-runtime-bounded-context.md`, `02-linux-sandbox-approximation-decisions.md`

Content rules:
- record competing designs when they exist
- capture why a decision was considered, not only what was selected
- allow contradictory designs to coexist until a decision is actually made

Current seeded documents:
- `01-cross-platform-runtime-bounded-context.md`
- `02-platform-specific-ui-shells-decision-space.md`