#!/bin/bash
# =============================================================================
# claudette.sh - Launch Claude Code backed by a local Ollama model
# =============================================================================
#
# Usage:
#   ./claudette.sh [model_name]
#
# Examples:
#   ./claudette.sh                     # Uses default model (qwen3-coder-next)
#   ./claudette.sh nemotron-cascade-2  # Uses a specific model
#
# This starts Claude Code connected to the local Ollama container instead
# of Anthropic's API. The environment variables are scoped to this process
# only - they do not affect other terminals or sessions.
#
# Requires:
#   - Ollama container running (./llm.sh on)
#   - The specified model already pulled/imported in Ollama
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
DEFAULT_MODEL="qwen3-coder-next"
OLLAMA_URL="http://localhost:11434"
MODEL="${1:-$DEFAULT_MODEL}"

# ---------------------------------------------------------------------------
# Check that the Ollama container is running
# ---------------------------------------------------------------------------
CONTAINER_NAME="ollama"
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
# Launch Claude Code pointed at the local Ollama instance
# ---------------------------------------------------------------------------
echo "Starting Claude Code with local model: $MODEL"
echo ""

ANTHROPIC_AUTH_TOKEN=ollama \
ANTHROPIC_API_KEY="" \
ANTHROPIC_BASE_URL="$OLLAMA_URL" \
CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
claude --model "$MODEL"
