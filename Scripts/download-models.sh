#!/usr/bin/env bash
# download-models.sh — Pre-downloads WhisperKit and FluidAudio models into the app bundle.
# Run this before building for the first time, or after a clean.
#
# Usage: ./Scripts/download-models.sh [--model <whisper-model-name>]
#
# Models are placed in CallTranscriber/Resources/Models/ and bundled by Package.swift.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
MODELS_DIR="$REPO_ROOT/CallTranscriber/Resources/Models"

WHISPER_MODEL="${1:-openai_whisper-small}"
HF_WHISPERKIT_ORG="argmaxinc/whisperkit-coreml"

echo "📦 CallTranscriber Model Downloader"
echo "   Models directory: $MODELS_DIR"
echo ""

mkdir -p "$MODELS_DIR"

# ---------------------------------------------------------------------------
# 1. WhisperKit CoreML model
# ---------------------------------------------------------------------------
WHISPER_DIR="$MODELS_DIR/$WHISPER_MODEL"

if [ -d "$WHISPER_DIR" ] && [ "$(ls -A "$WHISPER_DIR" 2>/dev/null)" ]; then
    echo "✅ WhisperKit model already present: $WHISPER_MODEL"
else
    echo "⬇️  Downloading WhisperKit model: $WHISPER_MODEL"

    # Check for huggingface-cli or git-lfs
    if command -v huggingface-cli &>/dev/null; then
        huggingface-cli download "$HF_WHISPERKIT_ORG" \
            --include "${WHISPER_MODEL}/*" \
            --local-dir "$MODELS_DIR" \
            --local-dir-use-symlinks False
    elif command -v git &>/dev/null && git lfs version &>/dev/null 2>&1; then
        TMP_DIR=$(mktemp -d)
        git clone --depth 1 "https://huggingface.co/$HF_WHISPERKIT_ORG" "$TMP_DIR"
        cp -r "$TMP_DIR/$WHISPER_MODEL" "$WHISPER_DIR"
        rm -rf "$TMP_DIR"
    else
        echo ""
        echo "⚠️  Neither huggingface-cli nor git-lfs found."
        echo "   Install one of:"
        echo "     pip install huggingface_hub[cli]"
        echo "     brew install git-lfs && git lfs install"
        echo ""
        echo "   Then re-run this script."
        exit 1
    fi

    echo "✅ WhisperKit model downloaded: $WHISPER_MODEL (~465MB)"
fi

# ---------------------------------------------------------------------------
# 2. FluidAudio diarization models
# ---------------------------------------------------------------------------
FLUID_DIR="$MODELS_DIR/diarization"

if [ -d "$FLUID_DIR" ] && [ "$(ls -A "$FLUID_DIR" 2>/dev/null)" ]; then
    echo "✅ FluidAudio diarization models already present"
else
    echo "⬇️  Downloading FluidAudio diarization models (~32MB)..."
    mkdir -p "$FLUID_DIR"

    # FluidAudio downloads its own models when first initialized at runtime,
    # caching to ~/Library/Caches/FluidAudio by default.
    # Here we pre-download them to a known location for bundling.
    if command -v huggingface-cli &>/dev/null; then
        huggingface-cli download "fluidinference/fluid-diarization-models" \
            --local-dir "$FLUID_DIR" \
            --local-dir-use-symlinks False
    else
        echo "ℹ️  FluidAudio models will be downloaded by the app on first launch."
        echo "   (Install huggingface-cli to pre-bundle them: pip install huggingface_hub[cli])"
        # Create a placeholder so the bundle resource path resolves
        touch "$FLUID_DIR/.placeholder"
    fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "✅ Done! Model sizes:"
du -sh "$WHISPER_DIR" 2>/dev/null || true
du -sh "$FLUID_DIR" 2>/dev/null || true
echo ""
echo "Build the app with: swift build -c release"
echo "   or open the project in Xcode."
