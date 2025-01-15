#!/bin/bash

# Load environment variables from .env file in current working directory
if [ -f "$(pwd)/.env" ]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ ! "$line" =~ ^#.*$ ]] && [[ -n "$line" ]]; then
            export "$line"
        fi
    done < "$(pwd)/.env"
else
    echo "Error: .env file not found in $(pwd)"
    exit 1
fi

# Verify HF_TOKEN exists
if [ -z "$HF_TOKEN" ]; then
    echo "Error: HF_TOKEN not found in .env file"
    exit 1
fi

# Use BASE_MODEL_DIR from env if set, otherwise fallback to default
BASE_DIR=${BASE_MODEL_DIR:-"models"}

# List of models to download
declare -a models=(
    "meta-llama/Llama-3.1-8B-Instruct"
    "mistralai/Ministral-8B-Instruct-2410"
    "Qwen/Qwen2.5-7B-Instruct"
    "seedboxai/merged_llama_sparse_dpo_experimental"
    "utter-project/EuroLLM-9B-Instruct"
    "google/gemma-2-9b-it"
    "openGPT-X/Teuken-7B-instruct-commercial-v0.4"
    "Aleph-Alpha/Pharia-1-LLM-7B-control"
    "BSC-LT/salamandra-7b-instruct"
    "meta-llama/Llama-3.1-8B"
    # Add more models here in the same format
)

# Create base directory if it doesn't exist
mkdir -p "$BASE_DIR"

# Function to convert model name to directory name
function get_dir_name() {
    echo "$1" | sed 's/\//-/g'
}

# Download each model
for model in "${models[@]}"; do
    echo "======================================"
    echo "Downloading $model"
    dir_name=$(get_dir_name "$model")
    target_dir="$BASE_DIR/$dir_name"

    # Create directory if it doesn't exist
    mkdir -p "$target_dir"

    # Download model
    huggingface-cli download "$model" \
        --local-dir "$target_dir" \
        --token "$HF_TOKEN"

    if [ $? -eq 0 ]; then
        echo "✓ Successfully downloaded $model"
    else
        echo "✗ Failed to download $model"
    fi

    echo "======================================"
done

echo "All downloads completed!"
ls -lh "$BASE_DIR"