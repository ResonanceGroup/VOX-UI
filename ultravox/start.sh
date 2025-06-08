#!/bin/bash
source "/workspace/ultravox_venv/bin/activate"
cd /workspace/ultravox-self-hosting-guide/ultravox_kokoro
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
python3 speech_server.py