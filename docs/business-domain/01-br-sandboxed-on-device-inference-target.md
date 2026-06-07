# 01 BR Sandboxed On-Device Inference Target

## Intent

This document is the overview for the on-device inference requirement cluster.

## Cluster Summary

The requirement cluster covers three distinct concerns:

1. which deployment environment is authoritative
2. how Linux approximates sandboxed deployment without becoming a desktop-only special case
3. how conversation-oriented runtime behavior must remain portable across those environments

## Detailed Documents

- [[03-br-apple-deployment-authority]]
- [[04-br-linux-sandbox-approximation-requirements]]
- [[05-br-conversation-oriented-inference-experience]]

## Still Covered Here

1. The product target remains a sandboxed on-device Apple deployment.
2. Approximation environments are valid only when they preserve that target's architectural consequences.

## Source Runbooks

- [[litert_lm_gemma4_swift_runbook]]