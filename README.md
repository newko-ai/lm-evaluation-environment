# lm-evaluation-environment

# LM Evaluation Environment

Automated setup for your language model evaluation workspace. This tool helps download and configure multiple language models for testing and evaluation.

## Quick Install

```bash
curl -sSL https://raw.githubusercontent.com/newko-ai/lm-evaluation-environment/refs/heads/main/setup-eval-workspace.sh | ([ "$(head -n1)" != "#!/bin/bash" ] && echo "Error: Invalid script" && exit 1 || bash)
```

## Manual Setup

1. Create a `.env` file in your project root:
```bash
HF_TOKEN=your_huggingface_token_here
BASE_MODEL_DIR=/path/to/your/models  # Optional, defaults to ./models
```

2. Run the model download script:
```bash
./helpers/download_models.sh
```

This will download the following models:
- meta-llama/Llama-3.1-8B
- meta-llama/Llama-3.1-8B-Instruct
- google/gemma-2-9b-it
- mistralai/Ministral-8B-Instruct-2410
- utter-project/EuroLLM-9B-Instruct
- Qwen/Qwen2.5-7B-Instruct
- openGPT-X/Teuken-7B-instruct-commercial-v0.4
- Aleph-Alpha/Pharia-1-LLM-7B-control
- BSC-LT/salamandra-7b-instruct

## Configuration

- `HF_TOKEN`: Your HuggingFace token with model download permissions
- `BASE_MODEL_DIR`: Optional directory for model storage (defaults to ./models)
```