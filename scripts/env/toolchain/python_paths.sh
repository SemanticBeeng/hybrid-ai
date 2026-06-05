#!/usr/bin/env bash

# Prevent an already-active host virtualenv from leaking into repository wrappers.
unset VIRTUAL_ENV
unset VIRTUAL_ENV_PROMPT
