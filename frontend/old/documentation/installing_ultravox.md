# UltraVOX Installation Guide

This guide provides detailed steps to install and set up UltraVOX based on a successful installation process.

---

## Prerequisites

- A cloud instance with GPU support (e.g., RunPod with RTX3090).
- Python 3.10 or higher.
- `curl` and `wget` installed.

---

## Installation Steps

### 1. Clone the UltraVOX Repository

Navigate to your desired directory and clone the UltraVOX repository:
```bash
git clone https://github.com/fixie-ai/ultravox.git
cd ultravox
```

### 2. Install Just (Task Runner)

UltraVOX uses Just for managing tasks. Install it with the following command:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to ~/.local/bin
```

Ensure the installation directory is in your PATH:
```bash
export PATH="$PATH:~/.local/bin"
```
Verify the installation:
```bash
just --version
```

### 3. Install Poetry

Poetry is used for dependency management. Install it with:
```bash
curl -sSL https://install.python-poetry.org | python3 -
```

Verify the installation:
```bash
poetry --version
```

### 4. Install Dependencies

Run the following command to install all required dependencies:
```bash
poetry install
```

### 5. Download Pre-trained Models

Download the UltraVOX pre-trained models using Git LFS:
```bash
git lfs install
git clone https://huggingface.co/fixie-ai/ultravox-v0_4
```

Place the downloaded model files in the appropriate directory as specified in the UltraVOX configuration.

### 6. Launch the Gradio Server

Start the UltraVOX Gradio-based server:
```bash
just gradio
```

Alternatively, if you don't have Just installed or prefer to run the server manually:
```bash
poetry shell
python gradio_demo.py
```

### 7. Access the Interface

Once the server starts, it will provide a URL such as:
```
Running on local URL: http://127.0.0.1:7860/
```

Open this URL in your browser to access the UltraVOX interface.

---

## Troubleshooting

- **Missing Dependencies:** Ensure all dependencies are installed with `poetry install`.
- **Port Issues:** Ensure port `7860` is open in your firewall settings.
- **Model Errors:** Confirm the pre-trained models are correctly placed and paths are configured.