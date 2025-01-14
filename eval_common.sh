#!/bin/bash

# eval_common.sh
#
# Common utilities and configurations for evaluation scripts

WORKSPACE_DIR="$(pwd)"
BASE_DIR="${WORKSPACE_DIR}/models"
RESULTS_DIR="${WORKSPACE_DIR}/results"

# Create results directory structure
create_results_structure() {
    local model_name=$1
    local eval_type=$2
    local timestamp=$(date +%Y%m%d_%H%M%S)

    # Create directory structure
    local run_dir="${RESULTS_DIR}/${model_name}/${timestamp}/${eval_type}"
    mkdir -p "$run_dir"
    echo "$run_dir"
}

# Validate model name
validate_model_name() {
    local model_name=$1
    if [ -z "$model_name" ]; then
        echo "Error: Model name cannot be empty"
        return 1
    fi

    local model_dir="$BASE_DIR/$model_name"
    if [ ! -d "$model_dir" ]; then
        echo "Error: Model directory not found: $model_dir"
        return 1
    fi
    return 0
}

# Power monitoring functions
start_power_monitoring() {
    local power_file=$1
    local log_file=$2

    echo "Starting power monitoring"
    echo "Power metrics output: $power_file"
    echo "Evaluation log: $log_file"

    # Start in background and store PID
    nohup python monitor_power.py "$power_file" "$log_file" >/dev/null 2>&1 &
    local pid=$!

    # Verify process started
    if ps -p $pid > /dev/null; then
        echo "Power monitoring started with PID: $pid"
        echo $pid > "/tmp/power_monitor.pid"
        return 0
    else
        echo "Failed to start power monitoring"
        return 1
    fi
}

stop_power_monitoring() {
    if [ -f "/tmp/power_monitor.pid" ]; then
        local pid
        pid=$(cat "/tmp/power_monitor.pid")
        echo "Stopping power monitoring (PID: $pid)"
        kill -SIGTERM "$pid" 2>/dev/null || true
        rm -f "/tmp/power_monitor.pid"
        wait "$pid" 2>/dev/null || true
    fi
}

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    stop_power_monitoring
    deactivate 2>/dev/null || true
    cd "$WORKSPACE_DIR"
}

#
# Single-run evaluation function (all tasks at once).
# (Kept for reference if you still want to do everything in one shot.)
#
run_eval() {
    local model_name="$1"
    local tasks="$2"
    local eval_type="$3"
    local venv_path="$4"
    local workspace_subdir="$5"

    # Validate model name
    if ! validate_model_name "$model_name"; then
        exit 1
    fi

    local model_dir="$BASE_DIR/$model_name"
    local run_dir
    run_dir=$(create_results_structure "$model_name" "$eval_type")

    local output_file="${run_dir}/results"
    local log_file="${run_dir}/eval.log"
    local power_file="${run_dir}/power.json"

    cat > "${run_dir}/metadata.json" <<EOF
{
    "model_name": "$model_name",
    "model_path": "$model_dir",
    "eval_type": "$eval_type",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "tasks": "$tasks"
}
EOF

    echo "======================================"
    echo "Running $eval_type evaluation for: $model_name"
    echo "======================================"
    echo "Results will be saved in: $run_dir"

    trap cleanup EXIT INT TERM

    if ! start_power_monitoring "$power_file" "$log_file"; then
        echo "Failed to start power monitoring"
        exit 1
    fi

    source "${venv_path}/bin/activate"
    cd "${WORKSPACE_DIR}/${workspace_subdir}"

    python -m lm_eval \
        --model hf \
        --model_args "pretrained=${model_dir}" \
        --tasks "$tasks" \
        --device "cuda:0" \
        --batch_size "auto:4" \
        --output_path "$output_file" \
        --log_samples \
        2>&1 | tee -a "$log_file"

    # Cleanup is handled by trap
}

#
# New function: run_eval_per_task
# This will loop over each task, run them individually with their own
# power monitoring session, and produce separate logs/results.
#
run_eval_per_task() {
    local model_name="$1"
    local task_list="$2"    # e.g. "arc_easy,arc_challenge,gsm8k"
    local eval_type="$3"    # e.g. "multilingual" or "english"
    local venv_path="$4"
    local workspace_subdir="$5"

    # Validate model name
    if ! validate_model_name "$model_name"; then
        exit 1
    fi

    local model_dir="$BASE_DIR/$model_name"

    # We'll create one "root" timestamped directory,
    # but each task will get its own subdirectory.
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local root_dir="${RESULTS_DIR}/${model_name}/${timestamp}"
    mkdir -p "$root_dir"

    echo "======================================"
    echo "Running $eval_type evaluation for: $model_name"
    echo "Tasks: $task_list"
    echo "======================================"
    echo "Root results will be in: $root_dir"
    echo

    # We won't set a global trap here because
    # we want to start/stop power monitoring *per task*.

    # Convert "arc_easy,arc_challenge,gsm8k" -> array
    IFS=',' read -ra tasks_array <<< "$task_list"

    source "${venv_path}/bin/activate"
    cd "${WORKSPACE_DIR}/${workspace_subdir}"

    # Iterate through each task
    for task_name in "${tasks_array[@]}"; do
        # Trim spaces just in case
        task_name="$(echo -e "${task_name}" | sed -e 's/^[[:space:]]*//')"

        echo "-------------------------------"
        echo "Evaluating single task: $task_name"
        echo "-------------------------------"

        # Create a directory for this one task
        local run_dir="${root_dir}/${eval_type}_${task_name}"
        mkdir -p "$run_dir"

        local output_file="${run_dir}/results"
        local log_file="${run_dir}/eval.log"
        local power_file="${run_dir}/power.json"

        # Write metadata for the single task
        cat > "${run_dir}/metadata.json" <<EOF
{
    "model_name": "$model_name",
    "model_path": "$model_dir",
    "eval_type": "$eval_type",
    "task": "$task_name",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

        if ! start_power_monitoring "$power_file" "$log_file"; then
            echo "Failed to start power monitoring for task $task_name."
            # up to you if you want to exit or continue
            continue
        fi

        python -m lm_eval \
            --model hf \
            --model_args "pretrained=${model_dir}" \
            --tasks "$task_name" \
            --device "cuda:0" \
            --batch_size "auto:4" \
            --output_path "$output_file" \
            --log_samples \
            2>&1 | tee -a "$log_file"

        stop_power_monitoring
        echo "Finished task: $task_name"
        echo "Results for this task in: $run_dir"
        echo
    done

    deactivate
    cd "$WORKSPACE_DIR"
}
