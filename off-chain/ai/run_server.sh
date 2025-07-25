#!/bin/bash

# Run Stablend AI FastAPI server

echo "Starting Stablend AI FastAPI server..."

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Virtual environment not found. Setting up..."
    ./setup_venv.sh
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Install dependencies if needed
echo "Installing dependencies..."
pip install -r requirements.txt

# Run the FastAPI server
echo "Starting FastAPI server on http://localhost:8000"
echo "API documentation available at http://localhost:8000/docs"
python start_server.py

# Deactivate virtual environment
deactivate

echo "Server stopped!" 