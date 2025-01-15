#!/bin/bash

# run-eval-eu.sh
#
# Example script for running "European multilingual" evaluations
source .env
source "${EVAL_ENV_DIR}/eval_common.sh"

EURO_TASKS="hellaswagx,arcx,truthfulqax" #,gsm8kx,belebele,flores200"
eval_type="multilingual"
venv_path="${WORKSPACE_DIR}/euro-eval-venv"
workspace_subdir="euro-eval-harness"

usage() {
    echo "Usage: $0 <model_name_or_list> [--per-task]"
    echo "Run European multilingual evaluation for one or more models."
    echo
    echo "  model_name_or_list   A single model name, or multiple names comma-separated."
    echo "                       e.g. 'my_model' or 'my_model_1,my_model_2'"
    echo "  --per-task           Run tasks one by one (monitors power usage per task)."
    echo
    echo "Examples:"
    echo "  $0 my_model"
    echo "  $0 my_model --per-task"
    echo "  $0 my_model_1,my_model_2"
    echo "  $0 my_model_1,my_model_2 --per-task"
}

# Main execution
if [ "$#" -lt 1 ]; then
    usage
    exit 1
fi

model_list="$1"
shift

# Just call the new function in eval_common.sh
run_evaluation_for_models \
    "$model_list" \
    "$EURO_TASKS" \
    "$eval_type" \
    "$venv_path" \
    "$workspace_subdir" \
    "$@"
