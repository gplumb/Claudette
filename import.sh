#!/bin/bash
# =============================================================================
# import.sh - Import a GGUF model into the running Ollama container
# =============================================================================
#
# Usage:
#   Local file:
#     ./import.sh <gguf_file> <model_name>
#
#   Download from HuggingFace:
#     ./import.sh --hf <repo_id> <gguf_filename> <model_name>
#
# Examples:
#   ./import.sh ~/Downloads/my-model.gguf my-model
#   ./import.sh --hf unsloth/Qwen3-Coder-Next-GGUF Qwen3-Coder-Next-UD-Q2_K_XL.gguf qwen3-coder-next
#
# This script:
#   - Requires the Ollama container to be running (via ./llm.sh on)
#   - In --hf mode, spins up a temporary container to download the GGUF
#     directly into the model volume (nothing installed on host)
#   - Generates a Modelfile and registers the model with Ollama
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
CONTAINER_NAME="ollama"
MODEL_DIR="$HOME/Documents/data/models"
HF_CONTAINER_NAME="huggingface-download"
HF_IMAGE_NAME="huggingface-downloader"

# ---------------------------------------------------------------------------
# Usage help
# ---------------------------------------------------------------------------
usage() {
    echo "Usage:"
    echo "  $0 <gguf_file> <model_name>"
    echo "  $0 --hf <repo_id> <gguf_filename> <model_name>"
    echo ""
    echo "Examples:"
    echo "  $0 ~/Downloads/my-model.gguf my-model"
    echo "  $0 --hf unsloth/Qwen3-Coder-Next-GGUF Qwen3-Coder-Next-UD-Q2_K_XL.gguf qwen3-coder-next"
    exit 1
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
# Check that the Ollama container is running
# ---------------------------------------------------------------------------
check_ollama() {
    if ! podman container exists "$CONTAINER_NAME" 2>/dev/null; then
        echo "Error: Ollama container '$CONTAINER_NAME' does not exist."
        echo "Start it first with: ./llm.sh on"
        exit 1
    fi

    local state
    state=$(podman inspect --format '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null)
    if [ "$state" != "running" ]; then
        echo "Error: Ollama container is not running (state: $state)."
        echo "Start it first with: ./llm.sh on"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Download a GGUF from HuggingFace using a temporary container
# The container mounts the model volume and downloads directly into it.
# It is stopped and removed when done - nothing touches the host.
# ---------------------------------------------------------------------------
download_from_hf() {
    local repo_id="$1"
    local gguf_filename="$2"

    ensure_model_dir

    echo "Starting HuggingFace download container..."
    echo "Downloading: $repo_id / $gguf_filename"
    echo "This may take a while for large models..."
    echo ""

    # Run the download in a temporary container.
    # The model volume is mounted at /models so the GGUF lands directly
    # in ~/Documents/data/models/ on the host.
    # Repo ID and filename are passed as environment variables to avoid
    # shell/Python quoting issues with special characters in filenames.
    podman run --rm \
        --name "$HF_CONTAINER_NAME" \
        --replace \
        -e "HF_REPO=${repo_id}" \
        -e "HF_FILE=${gguf_filename}" \
        -v "${MODEL_DIR}:/models:Z" \
        "$HF_IMAGE_NAME" \
        python -c "import os; from huggingface_hub import hf_hub_download; hf_hub_download(repo_id=os.environ['HF_REPO'], filename=os.environ['HF_FILE'], local_dir='/models')"

    echo "Download complete: ${MODEL_DIR}/${gguf_filename}"
}

# ---------------------------------------------------------------------------
# Register a GGUF with Ollama inside the running container
# ---------------------------------------------------------------------------
register_model() {
    local gguf_filename="$1"
    local model_name="$2"

    # The path inside the container - the model volume is mounted at /root/.ollama/
    local container_gguf_path="/root/.ollama/${gguf_filename}"

    echo "Creating Modelfile for model: $model_name"
    local modelfile_content="FROM ${container_gguf_path}
PARAMETER num_ctx 32768
PARAMETER temperature 1.0
PARAMETER top_p 0.95"

    # Write the Modelfile into the container
    podman exec "$CONTAINER_NAME" bash -c "cat > /tmp/Modelfile <<'INNEREOF'
${modelfile_content}
INNEREOF"

    # Register the model with Ollama
    echo "Registering model with Ollama (this may take a moment)..."
    podman exec "$CONTAINER_NAME" ollama create "$model_name" -f /tmp/Modelfile

    echo ""
    echo "Model '$model_name' imported successfully."
    echo ""
    echo "You can now use it with:"
    echo "  podman exec -it $CONTAINER_NAME ollama run $model_name"
    echo "  Or via Open WebUI at http://localhost:2000"
}

# ---------------------------------------------------------------------------
# Main: parse arguments and run the appropriate flow
# ---------------------------------------------------------------------------

# Need at least 2 arguments
if [ $# -lt 2 ]; then
    usage
fi

# Check Ollama is running before doing anything
check_ollama

if [ "$1" = "--hf" ]; then
    # ---------------------------------------------------------------------------
    # HuggingFace mode: ./import.sh --hf <repo_id> <gguf_filename> <model_name>
    # ---------------------------------------------------------------------------
    if [ $# -ne 4 ]; then
        echo "Error: --hf requires 3 arguments: <repo_id> <gguf_filename> <model_name>"
        echo ""
        usage
    fi

    HF_REPO="$2"
    GGUF_FILENAME="$3"
    MODEL_NAME="$4"

    # Download the GGUF into the model volume via container
    download_from_hf "$HF_REPO" "$GGUF_FILENAME"

    # Register with Ollama
    register_model "$GGUF_FILENAME" "$MODEL_NAME"

else
    # ---------------------------------------------------------------------------
    # Local file mode: ./import.sh <gguf_file> <model_name>
    # ---------------------------------------------------------------------------
    if [ $# -ne 2 ]; then
        usage
    fi

    GGUF_FILE="$1"
    MODEL_NAME="$2"

    # Validate the file exists
    if [ ! -f "$GGUF_FILE" ]; then
        echo "Error: File not found: $GGUF_FILE"
        exit 1
    fi

    ensure_model_dir

    # Copy the GGUF into the model volume
    GGUF_FILENAME=$(basename "$GGUF_FILE")
    DEST_PATH="${MODEL_DIR}/${GGUF_FILENAME}"

    echo "Copying GGUF to model volume..."
    cp "$GGUF_FILE" "$DEST_PATH"
    echo "Copied to: $DEST_PATH"

    # Register with Ollama
    register_model "$GGUF_FILENAME" "$MODEL_NAME"
fi
