#!/bin/bash

# Exit on error
set -e

source .env

if [ -z "$EVAL_ENV_DIR" ]; then
    echo "Error: EVAL_ENV_DIR environment variable is not set"
    exit 1
fi

echo "Updating evaluation environment at $EVAL_ENV_DIR..."

# Store the current directory
CURRENT_DIR=$(pwd)

# Change to the evaluation directory
cd "$EVAL_ENV_DIR"

# Reset and update the repository
echo "Resetting and updating repository..."
git reset --hard
git pull

# Make all shell scripts executable
echo "Making shell scripts executable..."
chmod +x *.sh

# Return to the original directory
cd "$CURRENT_DIR"

echo "Update completed successfully!"