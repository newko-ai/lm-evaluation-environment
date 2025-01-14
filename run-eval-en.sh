#!/bin/bash

# evaluate_en.sh
#
# Example script for running "standard English" evaluations

source "${EVAL_ENV_DIR}/eval_common.sh"

STANDARD_TASKS="arc_easy,arc_challenge,gsm8k,hellaswag,mmlu,truthfulqa"
eval_type="english"
venv_path="${WORKSPACE_DIR}/eval-venv"
workspace_subdir="eval-harness"

usage() {
    echo "Usage: $0 <model_name> [--per-task]"
    echo "Run standard English evaluation for a specific model."
    echo "  --per-task   Run tasks one by one (monitors power usage per task)."
    echo
    echo "Example: $0 model_name --per-task"
}

# Main execution
if [ "$#" -lt 1 ]; then
    usage
    exit 1
fi

model_name="$1"
shift

# Default: run them all at once
run_method="run_eval"

# If user passes "--per-task", we call run_eval_per_task instead
if [ "$1" == "--per-task" ]; then
    run_method="run_eval_per_task"
fi

if ! validate_model_name "$model_name"; then
    exit 1
fi

echo "======================================"
echo "Starting standard evaluation for: $model_name"
echo "Tasks: $STANDARD_TASKS"
echo "======================================"

"${run_method}" \
    "$model_name" \
    "$STANDARD_TASKS" \
    "$eval_type" \
    "$venv_path" \
    "$workspace_subdir"

echo "Evaluation completed. Results in ${RESULTS_DIR}/${model_name}."
