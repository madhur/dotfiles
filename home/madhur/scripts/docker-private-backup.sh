#!/bin/bash
# Docker private backup — thin wrapper.
#
# The logic now lives in the shared homelab lib
# (homelab.clients.git.backup_docker_private, exposed as `homelab-git
# backup-docker-private`): rsync ~/docker -> ~/docker-private, DB dumps, private
# .gitignore, LLM commit + push. Every step emits homelab metrics
# (service="git" / "claude_cli"). See ~/Desktop/python/lib/homelab.
exec /home/madhur/.virtualenvs/python-rsha/bin/homelab-git backup-docker-private
