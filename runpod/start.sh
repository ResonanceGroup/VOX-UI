#!/bin/bash
# Start script for UltraVox/Kokoro server on Runpod

# Activate the persistent venv
source /workspace/ultravox_venv/bin/activate

# Ensure HuggingFace cache is on persistent storage (use HF_HOME, not TRANSFORMERS_CACHE)
export HF_HOME=/workspace/hf_cache

# Change to the correct working directory
cd /workspace/ultravox-self-hosting-guide/ultravox_kokoro

# Start the server
python3 speech_server.py