#!/bin/bash
# =============================================================================
# download.sh - Download an Ollama model using a temporary online container
# =============================================================================
#
# Usage:
#   ./download.sh <model_name>
#
# Examples:
#   ./download.sh llama3
#   ./download.sh mistral:7b
#   ./download.sh codellama:13b
#
# This script:
#   - Creates a temporary container (ollama-download) with internet access
#   - Mounts the same model volume as the offline container
#   - Pulls the requested model
#   - Stops and removes the container when done (image stays on disk)
#   - Does NOT interfere with the running Ollama container
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
CONTAINER_NAME="ollama-download"
IMAGE_NAME="ollama-online"
MODEL_DIR="$HOME/Documents/data/models"

# ---------------------------------------------------------------------------
# Validate arguments
# ---------------------------------------------------------------------------
if [ -z "${1:-}" ]; then
    echo "Error: No model name provided."
    echo "Usage: $0 <model_name>"
    echo ""
    echo "Examples:"
    echo "  $0 llama3"
    echo "  $0 mistral:7b"
    exit 1
fi

MODEL_NAME="$1"

# ---------------------------------------------------------------------------
# Helper: ensure the model data directory exists on the host
# ---------------------------------------------------------------------------
ensure_model_dir() {
    if [ ! -d "$MODEL_DIR" ]; then
        echo "Creating model directory: $MODEL_DIR"
        mkdir -p "$MODEL_DIR"
    fi
}

# ---------------------------------------------------------------------------
# Cleanup: always stop and remove the download container on exit
# This ensures we don't leave an internet-connected container running
# ---------------------------------------------------------------------------
cleanup() {
    echo ""
    echo "Cleaning up download container..."
    podman stop "$CONTAINER_NAME" 2>/dev/null || true
    podman rm "$CONTAINER_NAME" 2>/dev/null || true
    echo "Download container removed."
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Main: start the download container, pull the model, then clean up
# ---------------------------------------------------------------------------
ensure_model_dir

echo "Starting temporary download container..."

# Start the ollama server in the background inside the container.
# No ports are mapped - this container is only for downloading.
# GPU is included so ollama can verify model compatibility.
podman run -d \
    --name "$CONTAINER_NAME" \
    --replace \
    --device nvidia.com/gpu=all \
    -v "${MODEL_DIR}:/root/.ollama:Z" \
    --tty \
    "$IMAGE_NAME"

# Wait for the ollama server to be ready inside the container.
# The server needs time to start - poll until it responds or we hit the timeout.
echo "Waiting for Ollama server to initialize..."
MAX_RETRIES=30
for i in $(seq 1 $MAX_RETRIES); do
    if podman exec "$CONTAINER_NAME" ollama list &>/dev/null; then
        echo "Ollama server is ready."
        break
    fi
    if [ "$i" -eq "$MAX_RETRIES" ]; then
        echo "Error: Ollama server failed to start after ${MAX_RETRIES} seconds."
        exit 1
    fi
    sleep 1
done

# Pull the requested model - this is the only reason this container exists
echo "Pulling model: $MODEL_NAME"
podman exec "$CONTAINER_NAME" ollama pull "$MODEL_NAME"

echo ""
echo "Model '$MODEL_NAME' downloaded successfully."
echo "It is now available in: $MODEL_DIR"
