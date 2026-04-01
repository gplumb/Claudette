#!/bin/bash
# =============================================================================
# build.sh - Build all Podman container images
# =============================================================================
#
# Usage:
#   ./build.sh
#
# Builds the following images:
#   - ollama-offline          (from OllamaOffline)  - offline LLM server
#   - ollama-online           (from OllamaOnline)   - temporary model downloader
#   - webui-offline           (from WebUI)          - offline Open WebUI
#   - huggingface-downloader  (from HuggingFace)    - temporary GGUF downloader
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Get the directory where this script lives (so it works from anywhere)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Building Ollama (offline)..."
podman build -f "$SCRIPT_DIR/OllamaOffline" -t ollama-offline "$SCRIPT_DIR"

echo ""
echo "Building Ollama (online/download)..."
podman build -f "$SCRIPT_DIR/OllamaOnline" -t ollama-online "$SCRIPT_DIR"

echo ""
echo "Building WebUI (offline)..."
podman build -f "$SCRIPT_DIR/WebUI" -t webui-offline "$SCRIPT_DIR"

echo ""
echo "Building HuggingFace downloader..."
podman build -f "$SCRIPT_DIR/HuggingFace" -t huggingface-downloader "$SCRIPT_DIR"

echo ""
echo "All images built successfully."
