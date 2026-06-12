# 05 BR Conversation-Oriented Inference Experience

## Intent

This document captures the product requirement that inference is experienced as one runtime serving many conversations rather than as isolated one-shot requests.

## Requirement Statements

1. The app must support many user conversations within one prepared runtime.
2. Conversation identity must remain explicit and stable while a runtime session is active.
3. Conversation transcripts must remain isolated from one another.
4. Runtime preparation cost should be amortized across multiple conversations when possible.
5. Conversation creation, selection, and deletion are product-level behaviors, not transport accidents.

## Ubiquitous Language

- `one runtime, many conversations`: the preferred ownership model where a prepared engine serves multiple active conversation threads
- `conversation identity`: the stable handle used to address one conversation over its lifetime
- `transcript isolation`: the property that messages from one conversation do not bleed into another

## Acceptance Implications

1. App state must expose multiple conversations, not just a single prompt-response lane.
2. Backend and Apple-native integrations should preserve equivalent conversation semantics.
3. Runtime APIs should expose lifecycle behavior that supports creation, listing, selection, and removal.

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]