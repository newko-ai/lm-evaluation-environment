#!/bin/bash

# evaluate_eu.sh
#
# Example script for running "European multilingual" evaluations

source "${EVAL_ENV_DIR}/eval_common.sh"

EURO_TASKS="arc_easy,arc_challenge,gsm8k,hellaswag,mmlu,truthfulqa,flores200_src,flores200_tgt"
eval_type="multilingual"
venv_path="${WORKSPACE_DIR}/euro-eval-venv"
workspace_subdir="euro-eval-harness"

usage() {
    echo "Usage: $0 <model_name>"
    echo "Run European multilingual evaluation for a specific model"
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
         "$EURO_TASKS" \
         "$eval_type" \
         "$venv_path" \
         "$workspace_subdir"

echo "Evaluation completed. Results in ${RESULTS_DIR}/${model_name}."
