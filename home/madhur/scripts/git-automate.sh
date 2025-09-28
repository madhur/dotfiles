#!/bin/bash

# Git Auto-commit Script - DEBUG VERSION
# Usage: ./git-autocommit.sh /path/to/parent/folder

# Temporarily disable set -e to debug
# set -e  

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to process a single git repository
process_repo() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    
    log "Processing repository: $repo_name at $repo_path"
    
    cd "$repo_path"
    local cd_exit=$?
    log "DEBUG: cd exit code: $cd_exit"
    
    # Check if there are any changes
    git status --porcelain > /tmp/git_status_output
    local git_status_exit=$?
    log "DEBUG: git status exit code: $git_status_exit"
    
    if [[ -z $(cat /tmp/git_status_output) ]]; then
        log "  No changes in $repo_name, skipping..."
        log "DEBUG: process_repo returning 0 (no changes)"
        return 0
    fi
    
    # Add all changes
    git add .
    local git_add_exit=$?
    log "DEBUG: git add exit code: $git_add_exit"
    log "  Added changes in $repo_name"
    
    # Commit with timestamp
    local commit_message="Auto-commit: $(date '+%Y-%m-%d %H:%M:%S')"
    git commit -m "$commit_message"
    local git_commit_exit=$?
    log "DEBUG: git commit exit code: $git_commit_exit"
    log "  Committed changes in $repo_name"
    
    # Check if remote exists and push
    if git remote | grep -q 'origin'; then
        local git_remote_exit=$?
        log "DEBUG: git remote check exit code: $git_remote_exit"
        
        # Check if current branch has upstream
        local current_branch=$(git branch --show-current)
        local branch_exit=$?
        log "DEBUG: git branch exit code: $branch_exit"
        
        if git rev-parse --verify "origin/$current_branch" >/dev/null 2>&1; then
            local verify_exit=$?
            log "DEBUG: git rev-parse exit code: $verify_exit"
            
            git push
            local git_push_exit=$?
            log "DEBUG: git push exit code: $git_push_exit"
            log "  Pushed changes in $repo_name"
        else
            log "  Warning: No upstream branch for $current_branch in $repo_name, skipping push"
        fi
    else
        log "  Warning: No remote 'origin' found in $repo_name, skipping push"
    fi
    
    log "DEBUG: process_repo finishing, about to return 0"
    return 0
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
    
    # Process each repository
    local success_count=0
    local error_count=0
    
    for repo in "${git_repos[@]}"; do
        log "DEBUG: About to call process_repo for: $repo"
        
        process_repo "$repo"
        local process_exit=$?
        log "DEBUG: process_repo returned exit code: $process_exit"
        
        if [[ $process_exit -eq 0 ]]; then
            success_count=$((success_count + 1))
            log "DEBUG: success_count is now: $success_count"
        else
            error_count=$((error_count + 1))
            log "DEBUG: error_count is now: $error_count"
            log "  Error processing $repo"
        fi
    done
    
    log "Process completed: $success_count successful, $error_count errors"
    log "DEBUG: About to exit with code 0"
    exit 0
}

# Check if script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log "DEBUG: Script starting, calling main function"
    main "$@"
    final_exit=$?
    log "DEBUG: main function returned: $final_exit"
    exit $final_exit
fi