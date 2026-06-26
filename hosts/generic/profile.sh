#!/usr/bin/env bash
# hosts/generic/profile.sh - safe defaults for non-LOQ systems
set -euo pipefail

HOST_DISPLAY_NAME="Generic Hyprland system"
HOST_DISPLAY="preferred"
PRIMARY_MONITOR=""
NVIDIA_MODE="${NVIDIA_MODE:-integrated}"
SWWW_PIXEL_FORMAT="${SWWW_PIXEL_FORMAT:-}"
THERMAL_PROFILE="balanced"

export HOST_DISPLAY_NAME HOST_DISPLAY PRIMARY_MONITOR NVIDIA_MODE SWWW_PIXEL_FORMAT THERMAL_PROFILE
