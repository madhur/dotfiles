#!/bin/bash
# Multi-repo git auto-commit — thin wrapper.
#
# Usage: git-automate.sh [/path/to/parent/folder]   (defaults to $PWD)
#
# The logic now lives in the shared homelab lib (homelab.clients.git.MultiRepoSync,
# exposed as `homelab-git sync-repos PATH`): stage every repo under PATH, generate
# ONE shared LLM commit message from the combined diff, then commit+push each dirty
# repo. Every step emits homelab metrics (service="git" / "claude_cli") to the
# Grafana homelab-api-llm dashboard. See ~/Desktop/python/lib/homelab.
exec /home/madhur/.virtualenvs/python-rsha/bin/homelab-git sync-repos "${1:-$PWD}"
