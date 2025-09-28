#!/bin/bash

# Git Utilities - Reusable functions for git operations
# Source this file in other scripts: source /path/to/git-utils.sh

# Function to log messages (can be overridden by sourcing script)
git_log_message() {
    local message="$1"
    if declare -f log_message > /dev/null 2>&1; then
        log_message "$message"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $message"
    fi
}

# Function to handle errors (can be overridden by sourcing script)
git_handle_error() {
    local message="$1"
    if declare -f handle_error > /dev/null 2>&1; then
        handle_error "$message"
    else
        echo "ERROR: $message" >&2
        exit 1
    fi
}

# Function to get the default branch name
get_default_branch() {
    git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main"
}

# Function to clean git state
clean_git_state() {
    if git status --porcelain | grep -q .; then
        git_log_message "WARNING: Repository has uncommitted changes, stashing them"
        git stash push -m "Auto-stash before backup $(date '+%Y-%m-%d %H:%M:%S')"
    fi
}

# Function to check if we're in a git repository
check_git_repo() {
    if [ ! -d ".git" ]; then
        git_handle_error "Not in a git repository. Current directory: $(pwd)"
    fi
}

# Function to get change statistics for commit message
get_change_stats() {
    local added_files modified_files deleted_files
    added_files=$(git diff --staged --name-status | grep -c "^A" || echo "0")
    modified_files=$(git diff --staged --name-status | grep -c "^M" || echo "0")
    deleted_files=$(git diff --staged --name-status | grep -c "^D" || echo "0")
    
    echo "$added_files $modified_files $deleted_files"
}

# Main function to add, commit, and push changes
# Usage: git_add_commit_push "commit message" [branch_name]
# If commit message is empty, will generate one automatically
# If branch_name is not provided, will use default branch
git_add_commit_push() {
    local commit_msg="$1"
    local branch_name="${2:-$(get_default_branch)}"
    local auto_commit_msg=""
    
    # Ensure we're in a git repository
    check_git_repo
    
    # Clean any uncommitted changes first
    # FIXED: Clean any uncommitted changes FIRST, before doing anything else
    # This should be called by the main script BEFORE syncing new data
    # clean_git_state  # Commented out - should be called before rsync, not here
    
    
    # Pull latest changes from remote
    git_log_message "Pulling latest changes from remote (branch: $branch_name)"
    if ! git pull origin "$branch_name"; then
        git_handle_error "Failed to pull from remote repository"
    fi
    
    # Add all files to git (including deletions)
    git_log_message "Staging changes"
    if ! git add -A; then
        git_handle_error "Failed to stage files"
    fi
    
    # Check if there are changes to commit
    if git diff --staged --quiet; then
        git_log_message "No changes detected since last backup"
        return 0
    fi
    
    # Get change statistics
    read -r added_files modified_files deleted_files <<< "$(get_change_stats)"
    
    # Generate commit message if not provided
    if [ -z "$commit_msg" ]; then
        auto_commit_msg="Auto-commit $(date '+%Y-%m-%d %H:%M:%S')"
        if [ "$added_files" != "0" ] || [ "$modified_files" != "0" ] || [ "$deleted_files" != "0" ]; then
            auto_commit_msg="$auto_commit_msg - A:$added_files M:$modified_files D:$deleted_files"
        fi
        commit_msg="$auto_commit_msg"
    fi
    
    # Commit changes
    git_log_message "Committing changes: $commit_msg"
    if ! git commit -m "$commit_msg"; then
        git_handle_error "Failed to commit changes"
    fi
    
    # Push to remote
    git_log_message "Pushing changes to remote repository (branch: $branch_name)"
    if ! git push origin "$branch_name"; then
        git_handle_error "Failed to push to remote repository"
    fi
    
    git_log_message "Git operations completed successfully"
    git_log_message "Changes: $added_files added, $modified_files modified, $deleted_files deleted"
    
    return 0
}

# Function for simple add and commit (without push)
# Usage: git_add_commit "commit message"
git_add_commit() {
    local commit_msg="$1"
    
    # Ensure we're in a git repository
    check_git_repo
    
    # Add all files to git (including deletions)
    git_log_message "Staging changes"
    if ! git add -A; then
        git_handle_error "Failed to stage files"
    fi
    
    # Check if there are changes to commit
    if git diff --staged --quiet; then
        git_log_message "No changes detected"
        return 0
    fi
    
    # Generate commit message if not provided
    if [ -z "$commit_msg" ]; then
        read -r added_files modified_files deleted_files <<< "$(get_change_stats)"
        commit_msg="Auto-commit $(date '+%Y-%m-%d %H:%M:%S') - A:$added_files M:$modified_files D:$deleted_files"
    fi
    
    # Commit changes
    git_log_message "Committing changes: $commit_msg"
    if ! git commit -m "$commit_msg"; then
        git_handle_error "Failed to commit changes"
    fi
    
    git_log_message "Commit completed successfully"
    return 0
}

# Function to setup a repository (clone or verify existing)
# Usage: git_setup_repo "repo_url" "local_path"
git_setup_repo() {
    local repo_url="$1"
    local local_path="$2"
    
    if [ -z "$repo_url" ] || [ -z "$local_path" ]; then
        git_handle_error "Usage: git_setup_repo <repo_url> <local_path>"
    fi
    
    # Create backup directory if it doesn't exist
    if [ ! -d "$local_path" ]; then
        git_log_message "Cloning repository for first time"
        if ! git clone "$repo_url" "$local_path"; then
            git_handle_error "Failed to clone repository"
        fi
    else
        # Verify it's actually a git repository
        if [ ! -d "$local_path/.git" ]; then
            git_handle_error "Directory exists but is not a git repository: $local_path"
        fi
        git_log_message "Using existing repository: $local_path"
    fi
}

# FIXED: New function to be called before syncing data
# This should be called BEFORE rsync, not during git operations
git_prepare_repo() {
    check_git_repo
    clean_git_state
}

# Function to get repository statistics
get_repo_stats() {
    local repo_size total_files
    repo_size=$(du -sh . | cut -f1)
    total_files=$(find . -type f | grep -v "\.git/" | wc -l)
    echo "Repository size: $repo_size, Total files: $total_files"
}