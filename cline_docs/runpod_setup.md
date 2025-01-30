
## Important Notes
- Only files in the `/workspace` directory persist between pod restarts
- All development work should be done in `/workspace` to ensure persistence

## Initial Setup

### 1. Setup Script
The `setup_pod.sh` script automates the installation of all required components on a fresh RunPod instance.

```bash
# First, ensure the script is in /workspace
cd /workspace

# Make the script executable
chmod +x setup_pod.sh

# Run the setup script
./setup_pod.sh
```

The script will:
- Install system dependencies
- Install Poetry
- Clone and install UltraVox SDK
- Set up environment variables
- Create necessary directories
- Configure PATH and environment persistence

After running the script, verify:
1. SSL certificates are in `/workspace/vox-backend/cert/`
2. API keys are configured in `/workspace/.env`
3. Backend files are in `/workspace/vox-backend/`

### 2. Manual Setup (if needed)
If you prefer to set up components manually:

```bash
cd /workspace

# Clone and install UltraVox Python SDK
git clone https://github.com/fixie-ai/ultravox-client-sdk-python.git
cd ultravox-client-sdk-python

# Install Poetry if not already installed
curl -sSL https://install.python-poetry.org | python3 -

# Install dependencies and build package
poetry install
poetry build

# Install the built package
pip install dist/*.whl

cd ..

# Move backend files to workspace
mv /vox-backend /workspace/
```

### 2. Python Environment Setup
```bash
cd /workspace/vox-backend
pip install -r requirements.txt
```

### 3. Required Environment Variables
- `ULTRAVOX_API_KEY` - Get from https://app.ultravox.ai

### 4. RunPod Configuration
1. **API Setup**:
   ```bash
   # Configure RunPod API key
   runpodctl config --apiKey=rpa_6Z64QX45BBE1GW8MYDSW659GBG5X643MQKPP6DT611gr1f
   ```

2. **Verify Configuration**:
   ```bash
   # List available pods
   runpodctl get pod
   ```

### 5. Directory Structure
```
/workspace/
├── ultravox-client-sdk-python/  # UltraVox Python SDK
└── vox-backend/                 # Our backend application
    ├── __init__.py
    ├── main.py
    ├── websocket.py
    ├── ultravox.py
    ├── kokoro.py
    └── requirements.txt
```

## GPU Configuration
- NVIDIA RTX 3090 GPU available
- CUDA and cuDNN support included in RunPod template
- GPU acceleration used for:
  - UltraVox speech-to-text processing
  - Kokoro TTS synthesis

## Networking
- WebSocket server runs on port 8000
- SSL certificates mounted at:
  - `/workspace/vox-backend/cert/cert.pem`
  - `/workspace/vox-backend/cert/key.pem`

## Starting the Server
```bash
cd /workspace/vox-backend
python main.py
```

## File Transfer

### Using the Transfer Script
1. **Install runpodctl** (on your local machine):
   ```powershell
   # Windows PowerShell
   wget https://github.com/runpod/runpodctl/releases/latest/download/runpodctl-windows-amd64.exe -O runpodctl.exe
   ```

2. **Using send_to_pod.ps1**:
   ```powershell
   # From the project root directory
   .\backend\send_to_pod.ps1
   ```
   
   The script will:
   - Create the destination directory on RunPod
   - Send each file individually
   - Set up proper permissions
   - Handle the transfer codes automatically

3. **Custom Destination**:
   ```powershell
   # Specify a different destination path
   .\backend\send_to_pod.ps1 -DestinationPath "/workspace/custom-path"
   ```

4. **Important Notes**:
   - Files are sent individually to avoid path prefix issues
   - The script automatically creates the destination directory
   - The setup script is made executable automatically
   - All files are placed directly in the specified directory

## Poetry Commands and Tips

### Basic Poetry Usage
```bash
# Initialize a new Poetry project
poetry init

# Install all dependencies
poetry install

# Add a new dependency
poetry add package-name

# Build the package
poetry build

# Run a command within the Poetry environment
poetry run python script.py
```

### Troubleshooting Poetry
1. **Poetry Environment Issues**:
   ```bash
   # Clear Poetry's cache
   poetry cache clear . --all
   
   # Update Poetry itself
   curl -sSL https://install.python-poetry.org | python3 -
   ```

2. **Build Issues**:
   ```bash
   # Force rebuild
   poetry install --no-cache
   ```

## Common Issues and Solutions
1. **File Persistence**: Always work in `/workspace` directory
2. **Python Package Installation**: Install packages globally since we're in a container
3. **GPU Access**: No special configuration needed, RunPod template handles GPU setup
4. **File Transfer**: Use runpodctl for reliable file transfer between local and RunPod
5. **Poetry Issues**: 
   - If Poetry fails to install dependencies, try clearing cache
   - For build errors, check Python version compatibility
   - Use `poetry debug info` to check environment information

## Deployment Checklist
- [ ] All files in `/workspace`
- [ ] UltraVox SDK installed
- [ ] Environment variables set
- [ ] SSL certificates in place
- [ ] Required Python packages installed
