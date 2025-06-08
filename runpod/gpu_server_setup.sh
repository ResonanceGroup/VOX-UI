#!/bin/bash
# gpu_server_setup.sh
# Setup script for UltraVox/Kokoro websocket server on RunPod PyTorch 2.0.1 template
# Uses a Python venv in /workspace for dependency persistence

set -e

echo "=== [UltraVox/KokoroTTS GPU Server Setup with venv] ==="

# 0. Install nano and screen for convenience
apt update
apt install nano screen -y

# 1. Verify GPU
if ! command -v nvidia-smi &> /dev/null; then
  echo "WARNING: NVIDIA drivers/CUDA not detected"
else
  echo "NVIDIA GPU detected:"
  nvidia-smi
fi

# 2. Clone the ultravox-self-hosting-guide repo if not present
REPO_DIR="/workspace/ultravox-self-hosting-guide"
if [ ! -d "$REPO_DIR" ]; then
  echo "Cloning ultravox-self-hosting-guide repository into $REPO_DIR"
  git clone https://github.com/avijeett007/ultravox-self-hosting-guide.git "$REPO_DIR"
else
  echo "ultravox-self-hosting-guide repo already exists at $REPO_DIR"
fi

# 2b. Overwrite the server script with the patched version
echo "Copying patched speech_server.py to repo (overwriting original)..."
cp "$(dirname "$0")/speech_server.py" "$REPO_DIR/ultravox_kokoro/speech_server.py"

# 3. Create Python venv in /workspace (persistent drive)
VENV_DIR="/workspace/ultravox_venv"
if [ ! -d "$VENV_DIR" ]; then
  echo "Creating Python venv at $VENV_DIR"
  python3 -m venv "$VENV_DIR"
else
  echo "Python venv already exists at $VENV_DIR"
fi

# 4. Activate venv and confirm
source "$VENV_DIR/bin/activate"
echo "Venv Python: $(which python)"
echo "Venv Pip: $(which pip)"

# 5. Use venv's pip explicitly for all installs, force-reinstall for clean env
$VENV_DIR/bin/pip install --upgrade pip
$VENV_DIR/bin/pip install --force-reinstall -r "$(dirname "$0")/requirements.txt"
# Ensure the latest transformers is installed
$VENV_DIR/bin/pip install --upgrade transformers

# 6. Clear the HuggingFace model cache for Ultravox to avoid config mismatches
echo "Clearing Ultravox model cache (if present)..."
rm -rf /workspace/hf_cache/modules/transformers_modules/fixie-ai/ultravox-v0_4/

echo "=== [Setup Complete] ==="
echo ""
echo "To start the websocket server, run:"
echo "  source $VENV_DIR/bin/activate"
echo "  export HF_HOME=/workspace/hf_cache"
echo "  cd $REPO_DIR"
echo "  ./start.sh"
echo ""
echo "If you see a rope_scaling or config error, try clearing the cache again and restarting."
echo "The server will listen on TCP port 7860 by default."
echo "Make sure to open port 7860 in your RunPod firewall/network settings."