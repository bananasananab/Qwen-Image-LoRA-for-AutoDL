#!/bin/bash
set -e

# ======================================================== #
#  Qwen Image LoRA Training - Cloud GPU Setup & Run        #
#  AutoDL + hf-mirror.com (HuggingFace blocked in China)   #
# ======================================================== #

# AutoDL path: /root/autodl-tmp is your data disk (100GB)
WORKSPACE="/root/autodl-tmp"
MODEL_DIR="$WORKSPACE/models"
OUTPUT_DIR="$WORKSPACE/output"
TOOLKIT_DIR="$WORKSPACE/ai-toolkit"
HF_CACHE="$WORKSPACE/hf_cache"

# ---- HuggingFace is blocked in China, use mirror ----
export HF_ENDPOINT="https://hf-mirror.com"
export HF_HOME="$HF_CACHE"
export HUGGINGFACE_HUB_CACHE="$HF_CACHE"
export TRANSFORMERS_CACHE="$HF_CACHE"
# hf_transfer for faster downloads (optional, may fail)
# export HF_HUB_ENABLE_HF_TRANSFER=1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[$(date +%H:%M:%S)]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo ""
echo "========================================"
echo "  Qwen Image LoRA Training - Cloud Setup"
echo "========================================"
echo ""

# --------------------------------------------------
# Step 1: Check that ai-toolkit code is in place
# --------------------------------------------------
log "[1/7] Checking ai-toolkit code..."
if [ ! -f "$TOOLKIT_DIR/run.py" ]; then
    err "ai-toolkit not found at $TOOLKIT_DIR.
    Please upload the ai-toolkit package first:
      Windows (local):  powershell -File scripts/package_for_cloud.ps1
      Then upload ai-toolkit-cloud.tar.gz to /root/autodl-tmp/ via JupyterLab
      Cloud:  mkdir -p /root/autodl-tmp/ai-toolkit
              tar -xzf /root/autodl-tmp/ai-toolkit-cloud.tar.gz -C /root/autodl-tmp/ai-toolkit"
fi
log "  OK - ai-toolkit found"

# --------------------------------------------------
# Step 2: Fix diffusers git URL (GitHub blocked)
# --------------------------------------------------
log "[2/7] Fixing GitHub URLs in requirements..."
python3 -c "
p='$TOOLKIT_DIR/requirements_base.txt'
c=open(p).read()
c=c.replace('git+https://github.com/huggingface/diffusers.git@dc8d9032171c83741fd37ed2b12bc9d8274464f3','diffusers>=0.38.0')
open(p,'w').write(c)
print('  requirements_base.txt fixed')
" || warn "  Could not fix requirements_base.txt"

# --------------------------------------------------
# Step 3: Install dependencies
# --------------------------------------------------
log "[3/7] Installing system dependencies..."
apt-get update -qq && apt-get install -y -qq wget > /dev/null 2>&1
log "  OK"

log "[4/7] Installing Python dependencies..."
cd "$TOOLKIT_DIR"
pip install --upgrade pip -q 2>&1 | tail -1
pip install diffusers>=0.38.0 -q 2>&1 | tail -1
pip install -r requirements.txt 2>&1 | tail -10
log "  OK"

# --------------------------------------------------
# Step 4: Create directories
# --------------------------------------------------
log "[5/7] Creating directories..."
mkdir -p "$MODEL_DIR" "$OUTPUT_DIR"
log "  OK"

# --------------------------------------------------
# Step 5: Download diffusion model (20GB) via hf-mirror
# --------------------------------------------------
log "[6/7] Downloading diffusion model (20GB, ~2-5 min)..."
MODEL_FILE="$MODEL_DIR/qwen_image_2512_fp8_e4m3fn.safetensors"
# Use hf-mirror.com CDN for the raw file download
MODEL_URL="https://hf-mirror.com/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_2512_fp8_e4m3fn.safetensors"

if [ -f "$MODEL_FILE" ]; then
    FILE_SIZE=$(stat -c%s "$MODEL_FILE" 2>/dev/null || echo 0)
    if [ "$FILE_SIZE" -gt 20000000000 ]; then
        log "  Model already downloaded ($((FILE_SIZE/1024/1024/1024))GB), skipping."
    else
        warn "  Incomplete download detected, re-downloading..."
        rm -f "$MODEL_FILE"
    fi
fi

if [ ! -f "$MODEL_FILE" ]; then
    wget -q --show-progress -O "$MODEL_FILE" "$MODEL_URL" || {
        warn "  wget failed, trying with Python requests..."
        python3 -c "
import urllib.request as r, sys
url='$MODEL_URL'
out='$MODEL_FILE'
print(f'Downloading {url}')
r.urlretrieve(url, out, lambda n,b,s: print(f'\r  {n*s//1048576}MB / 20000MB', end=''))
print('\nDone')
" || err "  Model download failed. Check network."
    }
    log "  Model downloaded successfully."
fi

# --------------------------------------------------
# Step 6: Pre-cache HuggingFace base model
# --------------------------------------------------
log "[7/7] Pre-downloading Qwen-Image base model (text encoder, VAE, tokenizer)..."
python3 -c "
import os
os.environ['HF_ENDPOINT'] = 'https://hf-mirror.com'
from transformers import Qwen2Tokenizer, Qwen2_5_VLForConditionalGeneration
from diffusers import AutoencoderKLQwenImage
print('  Downloading tokenizer...')
Qwen2Tokenizer.from_pretrained('Qwen/Qwen-Image', subfolder='tokenizer')
print('  Downloading text encoder (may take a few minutes)...')
Qwen2_5_VLForConditionalGeneration.from_pretrained('Qwen/Qwen-Image', subfolder='text_encoder', torch_dtype='bfloat16')
print('  Downloading VAE...')
AutoencoderKLQwenImage.from_pretrained('Qwen/Qwen-Image', subfolder='vae')
print('  Base model cached successfully.')
" || warn "  Pre-caching had issues, will download during training."

echo ""
echo "========================================"
echo "  Setup complete!"
echo "========================================"
echo ""
echo "  Model:    $MODEL_FILE"
echo "  Dataset:  $TOOLKIT_DIR/datasets/default"
echo "  Config:   $TOOLKIT_DIR/config/default.yaml"
echo "  Output:   $OUTPUT_DIR"
echo ""
echo "  Starting training..."
echo "========================================"
echo ""

# --------------------------------------------------
# Step 7: Run training
# --------------------------------------------------
cd "$TOOLKIT_DIR"
python3 run.py config/default.yaml

# --------------------------------------------------
# Done
# --------------------------------------------------
echo ""
echo "========================================"
echo "  Training finished!"
echo "  LoRA files are in: $OUTPUT_DIR"
echo "========================================"
