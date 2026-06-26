#!/usr/bin/env bash
set -euo pipefail

OUTDIR="${HOME}/Pictures/lumina-showcase"
mkdir -p "${OUTDIR}"

if ! command -v grimblast >/dev/null 2>&1; then
  lumina-toast "Screenshots unavailable" "Missing dependency: grimblast" error 2>/dev/null || true
  printf 'Missing dependency: grimblast\n' >&2
  exit 1
fi

sleep 1
grimblast save screen "${OUTDIR}/desktop.png"
if command -v lumina-shell >/dev/null 2>&1; then
  lumina-shell popup screenshot --body "Desktop captured" >/dev/null 2>&1 || true
else
  lumina-toast "Screenshot" "Desktop captured" success 2>/dev/null || true
fi

sleep 1
grimblast save active "${OUTDIR}/terminal.png" || true
walker >/dev/null 2>&1 &
sleep 0.5
grimblast save screen "${OUTDIR}/launcher.png"
pkill -x walker 2>/dev/null || true
if command -v lumina-shell >/dev/null 2>&1; then
  lumina-shell popup screenshot --body "Saved to ${OUTDIR}" >/dev/null 2>&1 || true
else
  lumina-toast "Screenshots" "Saved to ${OUTDIR}" success 2>/dev/null || true
fi
