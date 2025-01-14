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
        local pid=$(cat "/tmp/power_monitor.pid")
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
# The main "run_eval" function: it’s the single place that knows how to:
#   - Validate paths
#   - Create result directories
#   - Generate metadata.json
#   - Start/Stop power monitoring
#   - Activate the Python venv
#   - Run the evaluation
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

    # Create the model directory path
    local model_dir="$BASE_DIR/$model_name"

    # Create the standard run directory
    local run_dir
    run_dir=$(create_results_structure "$model_name" "$eval_type")

    # Prepare file paths
    local output_file="${run_dir}/results.json"
    local log_file="${run_dir}/eval.log"
    local power_file="${run_dir}/power.json"

    # Write metadata for traceability
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

    # Ensure we clean up whether success/failure
    trap cleanup EXIT INT TERM

    # Start power monitoring
    if ! start_power_monitoring "$power_file" "$log_file"; then
        echo "Failed to start power monitoring"
        exit 1
    fi

    # Activate the appropriate venv
    source "${venv_path}/bin/activate"

    # Run the evaluation
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

    # The cleanup trap will handle the rest
}
