#!/bin/bash
# =============================================================================
# overwrite.sh - Re-register an Ollama model with a custom Modelfile
# =============================================================================
#
# Usage:
#   ./overwrite.sh <model_name> <modelfile_path>
#
# Examples:
#   ./overwrite.sh qwen3-coder-next ./modelfiles/qwen3-coder-next.modelfile
#
# This script:
#   - Requires the Ollama container to be running (via ./llm.sh on)
#   - Copies the provided Modelfile into the container
#   - Re-registers the model with Ollama, overwriting the existing config
#   - The GGUF file must already exist in the model volume
#
# Use this to fix or customize a model's template, system prompt, stop
# tokens, or parameters without re-downloading the GGUF.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
CONTAINER_NAME="ollama"

# ---------------------------------------------------------------------------
# Usage help
# ---------------------------------------------------------------------------
usage() {
    echo "Usage: $0 <model_name> <modelfile_path>"
    echo ""
    echo "Re-register an existing model with a custom Modelfile."
    echo ""
    echo "Examples:"
    echo "  $0 qwen3-coder-next ./modelfiles/qwen3-coder-next.modelfile"
    exit 1
}

# ---------------------------------------------------------------------------
# Validate arguments
# ---------------------------------------------------------------------------
if [ $# -ne 2 ]; then
    usage
fi

MODEL_NAME="$1"
MODELFILE_PATH="$2"

# ---------------------------------------------------------------------------
# Validate the Modelfile exists
# ---------------------------------------------------------------------------
if [ ! -f "$MODELFILE_PATH" ]; then
    echo "Error: Modelfile not found: $MODELFILE_PATH"
    exit 1
fi

# ---------------------------------------------------------------------------
# Check that the Ollama container is running
# ---------------------------------------------------------------------------
if ! podman container exists "$CONTAINER_NAME" 2>/dev/null; then
    echo "Error: Ollama container '$CONTAINER_NAME' does not exist."
    echo "Start it first with: ./llm.sh on"
    exit 1
fi

STATE=$(podman inspect --format '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null)
if [ "$STATE" != "running" ]; then
    echo "Error: Ollama container is not running (state: $STATE)."
    echo "Start it first with: ./llm.sh on"
    exit 1
fi

# ---------------------------------------------------------------------------
# Copy the Modelfile into the container
# ---------------------------------------------------------------------------
echo "Copying Modelfile into container..."
podman cp "$MODELFILE_PATH" "${CONTAINER_NAME}:/tmp/Modelfile"

# ---------------------------------------------------------------------------
# Re-register the model with Ollama
# This overwrites the existing model config (template, params, etc.)
# but reuses the existing GGUF weights.
# ---------------------------------------------------------------------------
echo "Re-registering model '$MODEL_NAME' with new Modelfile..."
podman exec "$CONTAINER_NAME" ollama create "$MODEL_NAME" -f /tmp/Modelfile

echo ""
echo "Model '$MODEL_NAME' updated successfully."
echo ""
echo "You can now use it with:"
echo "  podman exec -it $CONTAINER_NAME ollama run $MODEL_NAME"
echo "  Or via Open WebUI at http://localhost:2000"
