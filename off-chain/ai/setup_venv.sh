#!/bin/bash

# Setup Python virtual environment for Stablend AI components

echo "Setting up Python virtual environment for Stablend AI..."

# Check if python3 is available
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is not installed. Please install python3 first."
    exit 1
fi

# Check if python3-venv is available
if ! python3 -c "import venv" &> /dev/null; then
    echo "Error: python3-venv is not installed. Please install it first:"
    echo "sudo apt install python3-venv"
    exit 1
fi

# Create virtual environment
echo "Creating virtual environment..."
python3 -m venv venv

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install requirements
echo "Installing Python dependencies..."
pip install -r requirements.txt

echo "Virtual environment setup complete!"
echo ""
echo "To activate the virtual environment in the future, run:"
echo "source venv/bin/activate"
echo ""
echo "To deactivate, run:"
echo "deactivate" 