#!/bin/bash
# =============================================================================
# webui.sh - Start or stop the Open WebUI container
# =============================================================================
#
# Usage:
#   ./webui.sh on    Start Open WebUI (requires Ollama to be running)
#   ./webui.sh off   Stop Open WebUI (preserves container state)
#
# The container:
#   - Runs with NO internet access (internal network only)
#   - Connects to Ollama over the shared internal network
#   - Exposes port 2000 on the host (mapped from 8080 inside)
#   - Mounts config/history data to ~/Documents/data/webui
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
CONTAINER_NAME="webui"
IMAGE_NAME="webui-offline"
NETWORK_NAME="ollama-internal"
OLLAMA_CONTAINER="ollama"
HOST_PORT="2000"
CONTAINER_PORT="8080"
DATA_DIR="$HOME/Documents/data/webui"

# ---------------------------------------------------------------------------
# Helper: ensure the shared internal podman network exists
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
# Helper: ensure the data directory exists on the host
# ---------------------------------------------------------------------------
ensure_data_dir() {
    if [ ! -d "$DATA_DIR" ]; then
        echo "Creating WebUI data directory: $DATA_DIR"
        mkdir -p "$DATA_DIR"
    fi
}

# ---------------------------------------------------------------------------
# Helper: check that the Ollama container is running
# WebUI is useless without Ollama, so we fail fast if it's not up.
# ---------------------------------------------------------------------------
check_ollama() {
    if ! podman container exists "$OLLAMA_CONTAINER" 2>/dev/null; then
        echo "Error: Ollama container '$OLLAMA_CONTAINER' does not exist."
        echo "Start it first with: ./llm.sh on"
        exit 1
    fi

    # Container exists, but is it actually running?
    local state
    state=$(podman inspect --format '{{.State.Status}}' "$OLLAMA_CONTAINER" 2>/dev/null)
    if [ "$state" != "running" ]; then
        echo "Error: Ollama container '$OLLAMA_CONTAINER' exists but is not running (state: $state)."
        echo "Start it first with: ./llm.sh on"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Start the WebUI container
# ---------------------------------------------------------------------------
start_webui() {
    check_ollama
    ensure_network
    ensure_data_dir

    echo "Starting Open WebUI container..."
    podman run -d \
        --name "$CONTAINER_NAME" \
        --replace \
        --network "$NETWORK_NAME" \
        -p "${HOST_PORT}:${CONTAINER_PORT}" \
        -v "${DATA_DIR}:/app/backend/data:Z" \
        --tty \
        "$IMAGE_NAME"

    echo "Open WebUI is running at http://localhost:$HOST_PORT"
}

# ---------------------------------------------------------------------------
# Stop the WebUI container (do NOT remove it)
# ---------------------------------------------------------------------------
stop_webui() {
    if podman container exists "$CONTAINER_NAME" 2>/dev/null; then
        echo "Stopping WebUI container..."
        podman stop "$CONTAINER_NAME"
        echo "WebUI stopped."
    else
        echo "WebUI container is not running."
    fi
}

# ---------------------------------------------------------------------------
# Main: parse the argument
# ---------------------------------------------------------------------------
case "${1:-}" in
    on)
        start_webui
        ;;
    off)
        stop_webui
        ;;
    *)
        echo "Usage: $0 {on|off}"
        exit 1
        ;;
esac
