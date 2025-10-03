#!/bin/bash

# Default configuration (can be overridden by ~/.ntfy_config)
NTFY_SERVER="https://ntfy.madhur.co.in"

# Load user configuration if exists
[ -f ~/.ntfy_config ] && source ~/.ntfy_config

# Function to format duration
format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    if [ $hours -gt 0 ]; then
        printf "%dh %dm %ds" $hours $minutes $secs
    elif [ $minutes -gt 0 ]; then
        printf "%dm %ds" $minutes $secs
    else
        printf "%ds" $secs
    fi
}

# Function to get system info
get_system_info() {
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    local memory_usage=$(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')
    local disk_usage=$(df -h / | awk 'NR==2{print $5}')
    
    echo "Load: $load_avg | Memory: $memory_usage | Disk: $disk_usage"
}

# Function to log events (console only)
log_event() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local level="$1"
    local topic="$2"
    local message="$3"
    
    echo "[$timestamp] [$level] [$topic] $message"
}

# Function to send rich notification - FIXED VERSION
send_rich_notification() {
    local topic="$1"
    local title="$2"
    local message="$3"
    local priority="${4:-default}"
    local tags="${5:-}"
    
    # Try different approaches based on what works with your server
    
    # Method 1: Simple POST with title in body (most compatible)
    local full_message="$title

$message"
    
    if curl -f -s -m 10 -d "$full_message" "$NTFY_SERVER/$topic" >/dev/null 2>&1; then
        return 0
    fi
    
    # Method 2: If your server supports headers, try this
    if curl -f -s -m 10 \
         -H "Title: $title" \
         -H "Priority: $priority" \
         ${tags:+-H "Tags: $tags"} \
         -d "$message" \
         "$NTFY_SERVER/$topic" >/dev/null 2>&1; then
        return 0
    fi
    
    # Method 3: If your server requires JSON, use this (with proper escaping)
    if command -v jq >/dev/null 2>&1; then
        local payload
        if [ -n "$tags" ]; then
            payload=$(jq -n \
                --arg topic "$topic" \
                --arg title "$title" \
                --arg message "$message" \
                --arg priority "$priority" \
                --arg tags "$tags" \
                '{topic: $topic, title: $title, message: $message, priority: $priority, tags: [$tags]}')
        else
            payload=$(jq -n \
                --arg topic "$topic" \
                --arg title "$title" \
                --arg message "$message" \
                --arg priority "$priority" \
                '{topic: $topic, title: $title, message: $message, priority: $priority}')
        fi
        
        curl -f -s -m 10 -X POST "$NTFY_SERVER" \
             -H "Content-Type: application/json" \
             -d "$payload" >/dev/null 2>&1
    else
        # Fallback: just send a simple message
        curl -f -s -m 10 -d "$full_message" "$NTFY_SERVER/$topic" >/dev/null 2>&1
    fi
}

# Enhanced function to execute command with rich notifications
run_with_notification() {
    local cmd="$1"
    local description="${2:-$(basename "${cmd%% *}")}"
    local topic="${3:-maintenance}"
    local notify_start="${4:-false}"
    
    local start_time=$(date +%s)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local hostname=$(hostname -s)
    local system_info=$(get_system_info)
    
    echo "[$timestamp] Starting: $description"
    log_event "START" "$topic" "$description"
    
    # Send start notification if enabled
    if [ "$notify_start" = "true" ]; then
        local start_msg="Started on $hostname at $timestamp
System: $system_info"
        send_rich_notification "$topic" "🚀 $description" "$start_msg" "default" "arrow_forward"
    fi
    
    # Execute the command and capture output
    local temp_output=$(mktemp)
    local exit_code=0
    
    if eval "$cmd" > "$temp_output" 2>&1; then

        exit_code=0
    else
        exit_code=$?
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local duration_formatted=$(format_duration $duration)
    local end_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local final_system_info=$(get_system_info)
    
    if [ $exit_code -eq 0 ]; then
        # Success notification
        local success_msg="✅ Completed successfully
⏱️ Duration: $duration_formatted
🖥️ Host: $hostname
📊 System: $final_system_info
🕐 Finished: $end_timestamp"
        
        send_rich_notification "$topic" "✅ $description" "$success_msg" "default" "white_check_mark"
        echo "[$end_timestamp] Completed successfully: $description (took $duration_formatted)"
        log_event "SUCCESS" "$topic" "$description - Duration: $duration_formatted"
    else
        # Failure notification with error details
        local error_output=$(tail -n 5 "$temp_output" | sed 's/$/\\n/' | tr -d '\n')
        local failure_msg="❌ Failed with exit code $exit_code
⏱️ Duration: $duration_formatted
🖥️ Host: $hostname
📊 System: $final_system_info
🕐 Failed at: $end_timestamp
🔍 Last 5 lines of output:
$error_output"
        
        send_rich_notification "$topic" "❌ $description" "$failure_msg" "high" "x"
        echo "[$end_timestamp] Failed: $description (exit code: $exit_code, took $duration_formatted)"
        log_event "FAILURE" "$topic" "$description - Exit: $exit_code, Duration: $duration_formatted"
    fi
    
    # Cleanup
    rm -f "$temp_output"
    return $exit_code
}

# Batch execution with summary
run_batch_with_notification() {
    local batch_name="$1"
    local topic="$2"
    shift 2
    local commands=("$@")
    
    local batch_start=$(date +%s)
    local batch_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local hostname=$(hostname -s)
    local total_tasks=${#commands[@]}
    
    # Start batch notification
    local batch_start_msg="📋 Starting batch execution
🖥️ Host: $hostname
📊 Tasks: $total_tasks
🕐 Started: $batch_timestamp"
    
    send_rich_notification "$topic" "📋 $batch_name" "$batch_start_msg" "default" "clipboard"
    log_event "BATCH_START" "$topic" "$batch_name - $total_tasks tasks"
    
    local success_count=0
    local failure_count=0
    local failed_tasks=()
    
    for i in "${!commands[@]}"; do
        local cmd="${commands[$i]}"
        local task_num=$((i + 1))
        local task_name="Task $task_num: $(basename "${cmd%% *}")"
        
        if run_with_notification "$cmd" "$task_name" "$topic" "false"; then
            ((success_count++))
        else
            ((failure_count++))
            failed_tasks+=("$task_name")
        fi
    done
    
    local batch_end=$(date +%s)
    local batch_duration=$((batch_end - batch_start))
    local batch_duration_formatted=$(format_duration $batch_duration)
    local batch_end_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Summary notification
    local summary_msg="📊 Batch execution completed
✅ Successful: $success_count
❌ Failed: $failure_count
⏱️ Total duration: $batch_duration_formatted
🖥️ Host: $hostname
🕐 Finished: $batch_end_timestamp"
    
    if [ $failure_count -gt 0 ]; then
        summary_msg="$summary_msg

🔍 Failed tasks:"
        for failed_task in "${failed_tasks[@]}"; do
            summary_msg="$summary_msg
• $failed_task"
        done
        send_rich_notification "$topic" "⚠️ $batch_name" "$summary_msg" "high" "warning"
        log_event "BATCH_PARTIAL" "$topic" "$batch_name - $success_count/$total_tasks succeeded"
    else
        send_rich_notification "$topic" "🎉 $batch_name" "$summary_msg" "default" "tada"
        log_event "BATCH_SUCCESS" "$topic" "$batch_name - All $total_tasks tasks succeeded"
    fi
    
    return $failure_count
}

# Debug function to test your ntfy server
test_ntfy_server() {
    echo "Testing ntfy server: $NTFY_SERVER"
    
    # Test 1: Basic connectivity
    echo "Test 1: Basic connectivity"
    if curl -f -s -m 5 "$NTFY_SERVER" >/dev/null; then
        echo "✅ Server is reachable"
    else
        echo "❌ Server unreachable"
        return 1
    fi
    
    # Test 2: Simple message
    echo "Test 2: Sending simple message"
    if curl -f -s -m 10 -d "Test message from script" "$NTFY_SERVER/test-topic-$(date +%s)"; then
        echo "✅ Simple message sent successfully"
    else
        echo "❌ Failed to send simple message"
    fi
    
    # Test 3: Message with headers
    echo "Test 3: Message with headers"
    if curl -f -s -m 10 \
         -H "Title: Test Title" \
         -H "Priority: normal" \
         -d "Test message with headers" \
         "$NTFY_SERVER/test-topic-$(date +%s)"; then
        echo "✅ Message with headers sent successfully"
    else
        echo "❌ Failed to send message with headers"
    fi
}

# Usage examples:
# test_ntfy_server
# run_with_notification "/path/to/cleanup.sh" "Database cleanup" "daily-tasks"
# run_with_notification "rsync -av /source/ /backup/" "Backup sync" "backup-tasks" "false"
# run_batch_with_notification "Daily Maintenance" "daily-tasks" "/path/to/cleanup.sh" "/path/to/backup.sh"