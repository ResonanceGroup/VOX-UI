#!/bin/bash

# Start UltraVOX in its own directory, log to ultravox.log
(
  cd /workspace/ultravox
  nohup poetry run python -m ultravox.server > ultravox.log 2>&1 &
)

# Start KokoroTTS in its own directory, log to kokoro.log
(
  cd /workspace/kokorotts
  nohup python3 server.py > kokoro.log 2>&1 &
)