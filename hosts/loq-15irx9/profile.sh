#!/usr/bin/env bash
# hosts/loq-15irx9/profile.sh — Host-specific variables for LOQ 15IRX9
set -euo pipefail

# Hardware identification
HOST_DISPLAY_NAME="Lenovo LOQ 15IRX9"
HOST_CPU="Intel Core i7-14700HX"
HOST_GPU_PRIMARY="Intel UHD Graphics (iGPU)"
HOST_GPU_SECONDARY="NVIDIA GeForce RTX 4060"
HOST_DISPLAY="1920x1080@144Hz"

# NVIDIA configuration mode
# Supported values: integrated, hybrid, nvidia.
# Default is integrated because this LOQ profile prioritizes sleep reliability,
# battery life, and low-maintenance Wayland behavior. Use hybrid/nvidia only
# after installing packages/optional-nvidia.txt and testing suspend/resume.
NVIDIA_MODE="${NVIDIA_MODE:-integrated}"

# Wallpaper daemon pixel format override. Leave empty to let swww auto-detect.
# Set to xrgb only if your GPU stack shows corruption with auto-detect.
SWWW_PIXEL_FORMAT="${SWWW_PIXEL_FORMAT:-}"

# Preferred monitor name (verify with: hyprctl monitors)
PRIMARY_MONITOR="eDP-1"

# Thermal profile preference
# balanced, performance, powersave
THERMAL_PROFILE="balanced"

# Export for use in other scripts
export HOST_DISPLAY_NAME HOST_CPU HOST_GPU_PRIMARY HOST_GPU_SECONDARY
export HOST_DISPLAY NVIDIA_MODE PRIMARY_MONITOR THERMAL_PROFILE SWWW_PIXEL_FORMAT

# ─── Conditional NVIDIA environment ──────────────────────────────────────────
# Set iGPU LibVA driver for 14th-gen Intel (iHD = Intel Media Driver)
export LIBVA_DRIVER_NAME="iHD"

# When in integrated mode, suppress NVIDIA Wayland env vars so wlroots
# uses the Intel iGPU correctly. In hybrid/nvidia mode, set them.
if [[ "${NVIDIA_MODE}" != "integrated" ]]; then
  export __GLX_VENDOR_LIBRARY_NAME="nvidia"
  export GBM_BACKEND="nvidia-drm"
  export __NV_PRIME_RENDER_OFFLOAD="1"
  export __NV_PRIME_RENDER_OFFLOAD_PROVIDER="NVIDIA-G0"
fi
