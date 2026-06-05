#!/bin/bash
# RedNotebook GitHub backup — thin wrapper.
#
# The logic now lives in the shared homelab lib
# (homelab.clients.git.backup_rednotebook, exposed as `homelab-git
# backup-rednotebook`). Routing through it means every rsync / git / commit-
# message-LLM step emits homelab metrics (service="git" / "claude_cli") to the
# Grafana homelab-api-llm dashboard. See ~/Desktop/python/lib/homelab.
exec /home/madhur/.virtualenvs/python-rsha/bin/homelab-git backup-rednotebook
