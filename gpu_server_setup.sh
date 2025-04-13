#!/bin/bash
# gpu_server_setup.sh
# Setup script for UltraVOX STT and Kokoro TTS servers on a cloud GPU (e.g., RunPod RTX 3090)
# Installs both services, sets up dependencies, and provides instructions for running both as accessible services.
# Idempotent: safe to run multiple times.

set -e

echo "=== [UltraVOX + KokoroTTS GPU Server Setup] ==="

# 1. Update system and install core dependencies
echo "Updating system and installing dependencies..."
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y python3 python3-pip git wget curl build-essential

# 2. (Optional) Install CUDA Toolkit if not present
if ! command -v nvidia-smi &> /dev/null; then
  echo "WARNING: NVIDIA drivers/CUDA not detected. Please install CUDA Toolkit manually if required for your GPU."
else
  echo "NVIDIA GPU detected."
fi

# 3. Clone UltraVOX server
if [ ! -d "ultravox" ]; then
  echo "Cloning UltraVOX server repository..."
  git clone https://github.com/fixie-ai/ultravox.git
else
  echo "UltraVOX server repo already exists. Pulling latest..."
  cd ultravox && git pull && cd ..
fi

# 4. Clone KokoroTTS server
if [ ! -d "kokorotts" ]; then
  echo "Cloning KokoroTTS server repository..."
  git clone https://github.com/kokorotts/kokorotts.git
else
  echo "KokoroTTS server repo already exists. Pulling latest..."
  cd kokorotts && git pull && cd ..
fi

# 5. Install Python dependencies for UltraVOX
echo "Installing UltraVOX Python dependencies..."
cd ultravox
pip3 install --upgrade pip
if [ -f requirements.txt ]; then
  pip3 install -r requirements.txt
elif [ -f pyproject.toml ]; then
  pip3 install poetry
  poetry install
else
  echo "WARNING: requirements.txt or pyproject.toml not found in ultravox."
fi
cd ..

# 6. Install Python dependencies for KokoroTTS
echo "Installing KokoroTTS Python dependencies..."
cd kokorotts
pip3 install --upgrade pip
# If there is a requirements.txt, install it; otherwise, try pip install .
if [ -f requirements.txt ]; then
  pip3 install -r requirements.txt
elif [ -f setup.py ]; then
  pip3 install .
else
  echo "No requirements.txt or setup.py found in kokorotts. If using npm, see KokoroTTS docs."
fi
cd ..

echo "=== [Manual Steps] ==="
echo "No manual model download or API keys are required for local use of UltraVOX or KokoroTTS."
echo "If you wish to run both as services:"
echo "  # Start UltraVOX (example, adjust as needed):"
echo "  cd ultravox && nohup poetry run python -m ultravox.server &"
echo "  # Start KokoroTTS (example, adjust as needed):"
echo "  cd kokorotts && nohup python3 server.py &"
echo "For production, use a process manager (systemd, supervisor) to keep services running."
echo "Ensure both services are accessible on the desired network interfaces/ports for VOX UI to connect."
echo "There is no official integration config between UltraVOX and KokoroTTS; they run as independent services."

echo "=== [Setup Complete] ==="
echo "UltraVOX and KokoroTTS servers are ready for manual launch and configuration."