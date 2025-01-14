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
    echo "Usage: $0 <model_name>"
    echo "Run standard English evaluation for a specific model"
    echo
    echo "Example: $0 my_model"
}

# Main execution
if [ "$#" -ne 1 ]; then
    usage
    exit 1
fi

model_name="$1"

# Call the central run_eval function
run_eval "$model_name" \
         "$STANDARD_TASKS" \
         "$eval_type" \
         "$venv_path" \
         "$workspace_subdir"

echo "Evaluation completed. Results in ${RESULTS_DIR}/${model_name}."
