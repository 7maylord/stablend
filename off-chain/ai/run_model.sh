#!/bin/bash

# Run Stablend AI model with virtual environment

echo "Running Stablend AI model..."

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Virtual environment not found. Setting up..."
    ./setup_venv.sh
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Run the model
echo "Running rate prediction model..."
python rateModel.py "$@"

# Deactivate virtual environment
deactivate

echo "Model execution complete!" 