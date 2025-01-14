#!/bin/bash

# evaluate_en.sh
#
# Example script for running "standard English" evaluations
source .env

source "${EVAL_ENV_DIR}/eval_common.sh"

STANDARD_TASKS="arc_easy,arc_challenge,gsm8k,hellaswag,mmlu,truthfulqa"
eval_type="english"
venv_path="${WORKSPACE_DIR}/eval-venv"
workspace_subdir="eval-harness"

usage() {
    echo "Usage: $0 <model_name_or_list> [--per-task]"
    echo "Run standard English evaluation for a specific model."
    echo
    echo "  model_name_or_list   A single model name, or multiple names comma-separated."
    echo "  --per-task           Run tasks one by one."
    echo
    echo "Examples:"
    echo "  $0 my_model"
    echo "  $0 my_model --per-task"
    echo "  $0 my_model_1,my_model_2 --per-task"
}

if [ "$#" -lt 1 ]; then
    usage
    exit 1
fi

model_list="$1"
shift

run_evaluation_for_models \
    "$model_list" \
    "$EN_TASKS" \
    "$eval_type" \
    "$venv_path" \
    "$workspace_subdir" \
    "$@"