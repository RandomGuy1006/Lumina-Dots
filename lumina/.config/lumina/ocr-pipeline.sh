#!/usr/bin/env bash
# Example OCR post-processing hook for lumina-dots.
#
# - Reads raw OCR text from stdin
# - Prints transformed text to stdout
# - Exit 0 and output non-empty text to override clipboard content
# - Exit 0 with empty output to keep the raw OCR result
#
# Install:
#   cp lumina/.config/lumina/ocr-pipeline.sh ~/.config/lumina/ocr-pipeline.sh
#   chmod +x ~/.config/lumina/ocr-pipeline.sh
#
set -euo pipefail

input="$(cat)"

# Example: trim extra whitespace without changing meaning.
printf '%s\n' "${input}" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
