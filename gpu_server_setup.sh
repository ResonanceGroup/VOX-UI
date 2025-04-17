#!/bin/bash
# gpu_server_setup.sh
# Complete server setup script that:
# 1. Installs Poetry if missing
# 2. Clones UltraVOX and KokoroTTS repos
# 3. Sets up both servers with dependencies

set -e

echo "=== [UltraVOX + KokoroTTS GPU Server Setup] ==="

# 1. Install Poetry if missing (only essential system package)
if ! command -v poetry &> /dev/null; then
  echo "Installing Poetry..."
  curl -sSL https://install.python-poetry.org | python3 -
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
  export PATH="$HOME/.local/bin:$PATH"
else
  echo "Poetry already installed"
fi

# 2. Verify GPU
if ! command -v nvidia-smi &> /dev/null; then
  echo "WARNING: NVIDIA drivers/CUDA not detected"
else
  echo "NVIDIA GPU detected:"
  nvidia-smi
fi

# 3. Clone UltraVOX server
if [ ! -d "ultravox" ]; then
  echo "Cloning UltraVOX server repository..."
  git clone https://github.com/fixie-ai/ultravox.git
else
  echo "UltraVOX server repo exists - pulling latest..."
  cd ultravox && git pull && cd ..
fi

# 4. Clone KokoroTTS server
if [ ! -d "kokorotts" ]; then
  echo "Cloning KokoroTTS server repository..."
  git clone https://github.com/kokorotts/kokorotts.git
else
  echo "KokoroTTS server repo exists - pulling latest..."
  cd kokorotts && git pull && cd ..
fi

# 5. Install UltraVOX dependencies
echo "Setting up UltraVOX..."
cd ultravox
if [ -f pyproject.toml ]; then
  poetry install
else
  echo "WARNING: No pyproject.toml found in ultravox"
fi
cd ..

# 6. Install KokoroTTS dependencies
echo "Setting up KokoroTTS..."
cd kokorotts
if [ -f requirements.txt ]; then
  pip install -r requirements.txt
elif [ -f setup.py ]; then
  pip install .
fi
cd ..

echo "=== [Setup Complete] ==="
echo "To start UltraVOX: cd ultravox && poetry run python -m ultravox.server"
echo "To start KokoroTTS: cd kokorotts && python server.py"