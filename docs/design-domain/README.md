# Design Domain

This folder tracks design-domain knowledge extracted from runbooks and implementation work.

Purpose:
- record design decisions, alternatives, tradeoffs, and bounded contexts
- preserve inconsistent or work-in-progress design directions without forcing premature resolution
- support reasoning across alternative architectures and implementation paths

Conventions:
- one Markdown file per design concern or bounded context
- file names use a two-digit prefix, then `bc` for bounded contexts or `dd` for design decisions, then an expressive name
- examples: [[01-bc-cross-platform-runtime-bounded-context]], [[02-dd-platform-specific-ui-shells-decision-space]]

Content rules:
- record competing designs when they exist
- capture why a decision was considered, not only what was selected
- allow contradictory designs to coexist until a decision is actually made

Current seeded documents:
- [[01-bc-cross-platform-runtime-bounded-context]]
- [[02-dd-platform-specific-ui-shells-decision-space]]

Additional detailed documents:
- [[03-dd-runtime-adapter-pattern]]
- [[04-dd-backend-transport-and-error-boundary]]
- [[05-dd-runtime-lifecycle-and-conversation-ownership]]
- [[06-dd-platform-ui-shell-separation]]
- [[07-dd-backend-conversation-contract]]
- [[08-dd-streaming-chat-semantics]]
- [[09-dd-model-bootstrap-and-runtime-pinning]]
- [[10-dd-backend-error-semantics]]
- [[11-dd-apple-native-runtime-adapter]]
- [[12-dd-apple-engine-and-conversation-lifecycle]]
- [[13-dd-linux-backend-runtime-adapter]]
- [[14-dd-linux-backend-runtime-and-conversation-lifecycle]]

Linux GPU note:
- the current promoted Linux GPU boundary is documented in [[13-dd-linux-backend-runtime-adapter]] and [[14-dd-linux-backend-runtime-and-conversation-lifecycle]]
- live Linux GPU serving remains experimental until the runtime can be promoted without broad host dynamic-linker mutation