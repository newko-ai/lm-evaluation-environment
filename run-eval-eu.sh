#!/bin/bash

# evaluate_eu.sh
#
# Example script for running "European multilingual" evaluations
source .env

source "${EVAL_ENV_DIR}/eval_common.sh"

EURO_TASKS="arc_easy,arc_challenge,gsm8k,hellaswag,mmlu,truthfulqa,flores200_src,flores200_tgt"
eval_type="multilingual"
venv_path="${WORKSPACE_DIR}/euro-eval-venv"
workspace_subdir="euro-eval-harness"

usage() {
    echo "Usage: $0 <model_name> [--per-task]"
    echo "Run European multilingual evaluation for a specific model."
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
echo "Starting multilingual evaluation for: $model_name"
echo "Tasks: $EURO_TASKS"
echo "======================================"

"${run_method}" \
    "$model_name" \
    "$EURO_TASKS" \
    "$eval_type" \
    "$venv_path" \
    "$workspace_subdir"

echo "Evaluation completed. Results in ${RESULTS_DIR}/${model_name}."
