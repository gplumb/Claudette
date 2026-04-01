#!/bin/bash
# =============================================================================
# llm.sh - Start or stop the Ollama LLM container
# =============================================================================
#
# Usage:
#   ./llm.sh on    Start the Ollama container (offline, GPU-enabled)
#   ./llm.sh off   Stop the Ollama container (preserves container state)
#
# The container:
#   - Runs with NO internet access (internal network only)
#   - Has GPU passthrough via NVIDIA CDI
#   - Mounts model data to ~/Documents/data/models
#   - Exposes port 11434 on the host
#   - Joins a shared internal network so WebUI can reach it
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
CONTAINER_NAME="ollama"
IMAGE_NAME="ollama-offline"
NETWORK_NAME="ollama-internal"
HOST_PORT="11434"
CONTAINER_PORT="11434"
MODEL_DIR="$HOME/Documents/data/models"

# ---------------------------------------------------------------------------
# Helper: ensure the shared internal podman network exists
# This network has no external routing - containers can talk to each other
# but cannot reach the internet.
# ---------------------------------------------------------------------------
ensure_network() {
    if ! podman network exists "$NETWORK_NAME" 2>/dev/null; then
        echo "Creating internal network: $NETWORK_NAME"
        podman network create \
            --internal \
            "$NETWORK_NAME"
    fi
}

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
# Start the Ollama container
# ---------------------------------------------------------------------------
start_ollama() {
    ensure_network
    ensure_model_dir

    echo "Starting Ollama container..."
    podman run -d \
        --name "$CONTAINER_NAME" \
        --replace \
        --network "$NETWORK_NAME" \
        --device nvidia.com/gpu=all \
        -p "${HOST_PORT}:${CONTAINER_PORT}" \
        -v "${MODEL_DIR}:/root/.ollama:Z" \
        --tty \
        "$IMAGE_NAME"

    echo "Ollama is running on port $HOST_PORT"
}

# ---------------------------------------------------------------------------
# Stop the Ollama container (do NOT remove it)
# ---------------------------------------------------------------------------
stop_ollama() {
    if podman container exists "$CONTAINER_NAME" 2>/dev/null; then
        echo "Stopping Ollama container..."
        podman stop "$CONTAINER_NAME"
        echo "Ollama stopped."
    else
        echo "Ollama container is not running."
    fi
}

# ---------------------------------------------------------------------------
# Main: parse the argument
# ---------------------------------------------------------------------------
case "${1:-}" in
    on)
        start_ollama
        ;;
    off)
        stop_ollama
        ;;
    *)
        echo "Usage: $0 {on|off}"
        exit 1
        ;;
esac
