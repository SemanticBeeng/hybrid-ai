# Business Domain

This folder tracks business-domain knowledge extracted from runbooks and other working documents.

Purpose:
- capture product-facing requirements in a stable, reusable form
- preserve ubiquitous language for the app, users, constraints, and outcomes
- separate enduring requirements from implementation details and work sequencing

Conventions:
- one Markdown file per requirement cluster or bounded business concern
- file names use a two-digit prefix, then `br` for business requirement, then an expressive name
- examples: [[01-br-sandboxed-on-device-inference-target]], [[05-br-conversation-oriented-inference-experience]]

Content rules:
- track requirements even when implementation is incomplete
- prefer requirement statements, constraints, acceptance criteria, and glossary terms
- do not use this folder for work breakdowns or speculative implementation details

Current seeded documents:
- [[01-br-sandboxed-on-device-inference-target]]
- [[02-br-cross-platform-swift-ui-delivery-target]]

Additional detailed documents:
- [[03-br-apple-deployment-authority]]
- [[04-br-linux-sandbox-approximation-requirements]]
- [[05-br-conversation-oriented-inference-experience]]
- [[06-br-shared-swift-core-portability-requirements]]