# Offline Ollama + Claude Code + Open WebUI (Podman)

A containerized setup for running Ollama and Claude Code locally using Podman. Designed for offline/air-gapped operation with internet access only for model downloads with optional WebUI chat interface (also offline).

These scripts assume a Linux Desktop. Podman will run on Windows and Mac, but you will need to modify these scripts for that.

## Pre-requisites

### Podman

Verify Podman is installed:

```bash
podman --version
```

### NVIDIA Container Toolkit (CDI)

GPU passthrough requires the NVIDIA Container Toolkit with CDI configured.

Verify the toolkit is installed:

```bash
nvidia-ctk --version
```

Verify the CDI spec exists:

```bash
ls /etc/cdi/nvidia.yaml 2>/dev/null || ls /var/run/cdi/nvidia.yaml 2>/dev/null
```

If the CDI spec is missing, generate it:

```bash
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
```

Smoke test — confirm GPU is accessible from a container:

```bash
podman run --rm --device nvidia.com/gpu=all ubuntu nvidia-smi
```

### Claude Code (Optional)
If you wish to use Claude Code with local models (what I have dubbed, Claudette), then you will need Claude Code installed.

## Quickstart

To get up and running quickly, you can just follow this section, but it's worth reading this document in its entirety.
Note. The podman containers mount volumes to here: `~/Documents/data/models` and `~/Documents/data/webui`

 - ./build.sh
 - ./llm.sh on
 - ./download.sh mistral:7b
 - ./webui.sh on 
 - ./claudette.sh mistral:7b

## Building the Images

Build all container images at once:

```bash
./build.sh
```

## Scripts

### Ollama LLM Server

Start the Ollama container (offline, GPU-enabled):

```bash
./llm.sh on
```

Stop the Ollama container:

```bash
./llm.sh off
```

- Container name: `ollama`
- Host port: `11434`
- Model data: `~/Documents/data/models`

### Download Models

Download a model from the ollama library (https://ollama.com/library) using a temporary internet-connected container:

```bash
./download.sh <model_name>
```

Examples:

```bash
./download.sh llama3
./download.sh mistral:7b
./download.sh codellama:13b
```

- Creates a temporary `ollama-download` container
- Downloads the model into the shared volume
- Automatically removes the container when done
- Does not interfere with the running Ollama container

### Import a GGUF Model

Import a GGUF model into the running Ollama container. Supports both local files and direct download from HuggingFace (without installing anything on the host).

**From HuggingFace (recommended):**

```bash
./import.sh --hf <repo_id> <gguf_filename> <model_name>
```

**From a local file:**

```bash
./import.sh <gguf_file> <model_name>
```

Example — importing Qwen3-Coder-Next from HuggingFace:

```bash
# 1. Make sure Ollama is running
./llm.sh on

# 2. Download and import in one step (no host dependencies needed)
./import.sh --hf unsloth/Qwen3-Coder-Next-GGUF Qwen3-Coder-Next-UD-Q2_K_XL.gguf qwen3-coder-next

# 3. Use it
podman exec -it ollama ollama run qwen3-coder-next
# Or via Open WebUI at http://localhost:2000
```

- Requires the Ollama container to be running
- In `--hf` mode, uses a temporary container to download — nothing installed on the host
- Registers the model with Ollama automatically

If registration fails and you need to clean up:

```bash
# Remove the GGUF from the model volume
rm ~/Documents/data/models/Qwen3-Coder-Next-UD-Q2_K_XL.gguf

# If the model was partially registered, remove it from Ollama
podman exec ollama ollama rm qwen3-coder-next
```

### Re-register a Model with a Custom Modelfile

Re-register an existing model with a custom template, system prompt, stop tokens, or parameters — without re-downloading the GGUF.

```bash
./overwrite.sh <model_name> <modelfile_path>
```

Example — fixing the Qwen3-Coder-Next chat template:

```bash
./overwrite.sh qwen3-coder-next ./modelfiles/qwen3-coder-next.modelfile
```

- Requires the Ollama container to be running
- The GGUF must already exist in the model volume
- Overwrites the model's config while reusing existing weights
- An example Modelfile can be found in this repo's `modelfiles/` directory

### Run Claude Code with Local Models

A shell script that launches Claude Code backed by your local Ollama instance instead of Anthropic's API. Environment variables are scoped to the launched process only — they do not affect other terminals or sessions.

```bash
./claudette.sh [model_name]
```

Examples:

```bash
./claudette.sh                     # Uses default model (qwen3-coder-next)
./claudette.sh nemotron-cascade-2  # Uses a specific model
```

- Requires the Ollama container to be running
- The specified model must already be pulled/imported
- All traffic goes to local Ollama — no Anthropic API calls or billing
- Telemetry to Anthropic is disabled
- Can be run from VS Code's integrated terminal for the full Claude Code experience

### WebUI

Start Open WebUI (requires Ollama to be running):

```bash
./webui.sh on
```

Stop Open WebUI:

```bash
./webui.sh off
```

- Container name: `webui`
- Host port: `2000`
- Config/history data: `~/Documents/data/webui`
- Access at: http://localhost:2000

## Architecture

- All containers run in Podman (rootless)
- Ollama and WebUI share an internal network (`ollama-internal`) with no external routing
- Internet access is disabled for all containers except the temporary download containers (`ollama-download` and `huggingface-download`)
- GPU passthrough via NVIDIA CDI
- Model data persists on the host at `~/Documents/data/models`

## Network Isolation

The `ollama` and `webui` containers run on a shared internal podman network (`ollama-internal`) with **no external routing**. This means they can communicate with each other but cannot reach the internet.

The network is created with the `--internal` flag, which prevents any outbound traffic beyond the network boundary:

```bash
podman network create --internal ollama-internal
```

Only the temporary containers (`ollama-download` and `huggingface-download`) have internet access, and they are automatically removed after use.

### Verifying network isolation

Confirm the network is marked as internal:

```bash
podman network inspect ollama-internal | grep -E '"internal"|"name"'
```

Expected output:

```
"name": "ollama-internal",
"internal": true,
```

Confirm each container is only attached to the internal network:

```bash
podman inspect ollama --format '{{json .NetworkSettings.Networks}}' | python3 -m json.tool
podman inspect webui --format '{{json .NetworkSettings.Networks}}' | python3 -m json.tool
```

Both should show only `ollama-internal` — no `bridge` or `default` network.

Test that outbound internet is unreachable from inside each container:

```bash
# Ollama — raw TCP test (curl not available in this image)
podman exec ollama bash -c "cat < /dev/tcp/8.8.8.8/53"
# Expected: "Network is unreachable"

# WebUI — HTTP test via Python
podman exec webui bash -c "python3 -c \"import urllib.request; urllib.request.urlopen('http://google.com', timeout=5)\""
# Expected: "OSError: [Errno 101] Network is unreachable"
```

Both commands should fail. If either succeeds, the container has unintended internet access.
