#!/bin/bash

# Git Auto-commit Script - DEBUG VERSION
# Usage: ./git-autocommit.sh /path/to/parent/folder
#
# Two-pass flow:
#   Pass A: for each repo, stage changes and capture the combined diff.
#   One LLM call: feed the combined diff to generate_llm_commit_message
#   so every repo gets the SAME, content-aware message this run.
#   Pass B: commit (using the shared message) and push each repo with changes.

# Temporarily disable set -e to debug
# set -e

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=/home/madhur/scripts/git-utils.sh
source "$SCRIPT_DIR/git-utils.sh"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Stage any changes in a repo. Echoes the repo's staged diff on stdout
# (prefixed with a header naming the repo) if there were changes, otherwise
# nothing. Returns 0 if changes were staged, 1 if the repo was clean.
stage_repo() {
    local repo_path="$1"
    local repo_name
    repo_name=$(basename "$repo_path")

    cd "$repo_path" || return 1

    if [[ -z $(git status --porcelain) ]]; then
        log "  No changes in $repo_name, skipping..." >&2
        return 1
    fi

    git add . >&2
    log "  Staged changes in $repo_name" >&2

    # Confirm staging produced a non-empty diff (e.g. ignored-only changes
    # would leave nothing staged).
    if git diff --staged --quiet; then
        log "  Nothing staged after git add in $repo_name, skipping..." >&2
        return 1
    fi

    printf '\n===== repo: %s (%s) =====\n' "$repo_name" "$repo_path"
    git diff --staged --stat
    printf '\n'
    git diff --staged
    return 0
}

# Commit (with the shared message) and push a repo that has staged changes.
commit_and_push_repo() {
    local repo_path="$1"
    local commit_message="$2"
    local repo_name
    repo_name=$(basename "$repo_path")

    cd "$repo_path" || return 1

    git commit -m "$commit_message"
    log "  Committed changes in $repo_name"

    if git remote | grep -q 'origin'; then
        local current_branch
        current_branch=$(git branch --show-current)

        if git rev-parse --verify "origin/$current_branch" >/dev/null 2>&1; then
            git push
            log "  Pushed changes in $repo_name"
        else
            log "  Warning: No upstream branch for $current_branch in $repo_name, skipping push"
        fi
    else
        log "  Warning: No remote 'origin' found in $repo_name, skipping push"
    fi
}

# Main function
main() {
    local search_path="${1:-$PWD}"

    if [[ ! -d "$search_path" ]]; then
        log "Error: Directory $search_path does not exist"
        exit 1
    fi

    log "Starting git auto-commit process in: $search_path"

    # Find all .git directories (repositories)
    local git_repos=()
    while IFS= read -r -d '' git_dir; do
        repo_dir=$(dirname "$git_dir")
        git_repos+=("$repo_dir")
    done < <(find "$search_path" -type d -name ".git" -print0 2>/dev/null)

    if [[ ${#git_repos[@]} -eq 0 ]]; then
        log "No git repositories found in $search_path"
        exit 0
    fi

    log "Found ${#git_repos[@]} git repositories"

    # --- Pass A: stage everything, collect combined diff ---
    local dirty_repos=()
    local combined_diff_file
    combined_diff_file=$(mktemp -t git-automate-diff.XXXXXX)
    # shellcheck disable=SC2064
    trap "rm -f '$combined_diff_file'" EXIT

    for repo in "${git_repos[@]}"; do
        log "Pass A: staging $repo"
        if stage_repo "$repo" >> "$combined_diff_file"; then
            dirty_repos+=("$repo")
        fi
    done

    if [[ ${#dirty_repos[@]} -eq 0 ]]; then
        log "No repos with changes; nothing to commit."
        exit 0
    fi

    log "Pass A complete: ${#dirty_repos[@]} repo(s) with staged changes"

    # --- One LLM call for the whole batch ---
    local commit_message=""
    if [ -s "$combined_diff_file" ]; then
        log "Generating shared commit message via LLM (one call for all repos)"
        commit_message=$(generate_llm_commit_message < "$combined_diff_file" 2>/dev/null || true)
    fi
    if [ -z "$commit_message" ]; then
        commit_message="Auto-commit: $(date '+%Y-%m-%d %H:%M:%S')"
        log "LLM message unavailable; using fallback: $commit_message"
    else
        log "LLM message: $(printf '%s' "$commit_message" | head -1)"
    fi

    # --- Pass B: commit + push each dirty repo with the shared message ---
    local success_count=0
    local error_count=0

    for repo in "${dirty_repos[@]}"; do
        log "Pass B: committing $repo"
        if commit_and_push_repo "$repo" "$commit_message"; then
            success_count=$((success_count + 1))
        else
            error_count=$((error_count + 1))
            log "  Error processing $repo"
        fi
    done

    log "Process completed: $success_count successful, $error_count errors"
    exit 0
}

# Check if script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
