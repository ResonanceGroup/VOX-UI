#!/bin/bash

# Exit on any error
set -e

echo "Starting RunPod setup..."

# Create workspace structure if it doesn't exist
mkdir -p /workspace/vox-backend

# Install system dependencies
echo "Installing system dependencies..."
apt-get update
apt-get install -y curl git python3-pip

# Install Poetry
echo "Installing Poetry..."
curl -sSL https://install.python-poetry.org | python3 -
export PATH="/root/.local/bin:$PATH"

# Clone and install UltraVox SDK
echo "Setting up UltraVox SDK..."
cd /workspace
if [ ! -d "ultravox-client-sdk-python" ]; then
    git clone https://github.com/fixie-ai/ultravox-client-sdk-python.git
fi
cd ultravox-client-sdk-python
poetry install
poetry build
pip install dist/*.whl

# Install our backend dependencies
echo "Installing backend dependencies..."
cd /workspace/vox-backend
pip install -r requirements.txt

# Configure environment variables
echo "Setting up environment variables..."
if [ ! -f "/workspace/.env" ]; then
    echo "ULTRAVOX_API_KEY=your_api_key_here" > /workspace/.env
    echo "Please update /workspace/.env with your actual API keys"
fi

# Create SSL certificate directory
echo "Setting up SSL certificates directory..."
mkdir -p /workspace/vox-backend/cert

echo "Setup complete! Please ensure:"
echo "1. SSL certificates are in /workspace/vox-backend/cert/"
echo "2. API keys are configured in /workspace/.env"
echo "3. Backend files are in /workspace/vox-backend/"

# Add environment variables to .bashrc for persistence
echo 'export PATH="/root/.local/bin:$PATH"' >> ~/.bashrc
echo 'source /workspace/.env' >> ~/.bashrc
