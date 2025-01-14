#!/bin/bash

# Exit on error
set -e

echo "Starting LLM evaluation environment setup..."

# Install required packages
echo "Installing required packages..."
apt-get update
apt-get install -y nano git python3-venv

# Setup .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "Creating example .env file..."
    cat > .env.example << EOL
# Hugging Face token for model downloads
HF_TOKEN=your_token_here

# Base directory for model storage
BASE_MODEL_DIR=./models

# Optional: Proxy settings if needed
# HTTP_PROXY=http://proxy.example.com:8080
# HTTPS_PROXY=http://proxy.example.com:8080
EOL

    cp .env.example .env
    chmod 600 .env
    echo "Please edit .env file with your settings before continuing."
    echo "You can do this by running: nano .env"
    exit 1
else
    echo "Checking .env file configuration..."
    # Source the .env file to get variables
    set -a
    source .env
    set +a

    if [ -z "$HF_TOKEN" ]; then
        echo "Warning: HF_TOKEN not found in .env file"
        echo "Please ensure your .env file contains all required variables"
        exit 1
    fi

    # Set default model directory if not specified
    if [ -z "$BASE_MODEL_DIR" ]; then
        echo "BASE_MODEL_DIR not set in .env, using default: ./models"
        BASE_MODEL_DIR="./models"
    fi
    echo ".env file exists and contains required variables."
fi

# Create directories using BASE_MODEL_DIR
echo "Creating model directory at: $BASE_MODEL_DIR"
mkdir -p "$BASE_MODEL_DIR"

# Create Python virtual environments
echo "Creating virtual environments..."
python3 -m venv eval-venv
python3 -m venv euro-eval-venv

# Clone repositories
echo "Cloning repositories..."
git clone https://github.com/EleutherAI/lm-evaluation-harness eval-harness
git clone https://github.com/OpenGPTX/lm-evaluation-harness euro-eval-harness
git clone https://github.com/newko-ai/lm-evaluation-environment eval-environment

# Setup euro-eval environment
echo "Setting up euro-eval environment..."
source euro-eval-venv/bin/activate
cd euro-eval-harness
pip install --upgrade pip
pip install -e .
cd ..
deactivate

# Setup eval environment
echo "Setting up eval environment..."
source eval-venv/bin/activate
cd eval-harness
pip install --upgrade pip
pip install -e .
cd ..
deactivate

# Make evaluation pipeline scripts executable
echo "Making evaluation pipeline scripts executable..."
chmod +x eval-environment/*.sh

# Check if models directory is empty and run download script if needed
if [ -z "$(ls -A "$BASE_MODEL_DIR")" ]; then
    echo "Models directory is empty, downloading models..."
    ./eval-environment/download-models.sh
else
    echo "Models directory is not empty, skipping model download."
fi

echo "Setup completed successfully!"

# Delete this script
echo "Cleaning up setup script..."
rm -- "$0"