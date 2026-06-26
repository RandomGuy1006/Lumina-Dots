#!/usr/bin/env bash
# Capture a screen region, OCR it, optionally refine it, and copy the result.
set -euo pipefail

tmp_image="$(mktemp --suffix=.png)"
chmod 600 "${tmp_image}"
trap 'rm -f "${tmp_image}"' EXIT
state_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/lumina/ocr"
mkdir -p "${state_dir}"

for cmd in grim slurp tesseract wl-copy; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    lumina-toast "OCR" "Missing dependency: ${cmd}" error 2>/dev/null || true
    exit 1
  fi
done

geometry="$(slurp 2>/dev/null || true)"
[[ -n "${geometry}" ]] || exit 0

grim -g "${geometry}" "${tmp_image}"
text="$(tesseract "${tmp_image}" stdout -l eng 2>/dev/null | sed '/^[[:space:]]*$/d')"

if [[ -z "${text}" ]]; then
  lumina-toast "OCR" "No text detected" warning 2>/dev/null || true
  exit 1
fi

mode="${LUMINA_OCR_MODE:-smart}"
model="${LUMINA_OCR_MODEL:-llama3.2:3b}"
pipeline="${LUMINA_OCR_PIPELINE:-${HOME}/.config/lumina/ocr-pipeline.sh}"
result="${text}"
label="recognized text"

run_ollama() {
  local prompt="$1"

  command -v ollama >/dev/null 2>&1 || return 1
  timeout "${LUMINA_OCR_TIMEOUT:-25}" ollama run "${model}" "${prompt}" 2>/dev/null |
    sed '/^[[:space:]]*$/d'
}

if [[ -x "${pipeline}" ]]; then
  refined="$(printf '%s\n' "${text}" | "${pipeline}" 2>/dev/null || true)"
  if [[ -n "${refined}" ]]; then
    result="${refined}"
    label="pipeline output"
  fi
elif [[ "${mode}" != "raw" ]]; then
  case "${mode}" in
    translate)
      prompt=$'Translate this OCR text into concise natural English. Return only the translation:\n\n'"${text}"
      ;;
    summarize | smart)
      prompt=$'Clean OCR errors and summarize the useful content in 1-3 short bullets. Return only the refined text:\n\n'"${text}"
      ;;
    *)
      prompt=$'Clean obvious OCR errors. Return only the corrected text:\n\n'"${text}"
      ;;
  esac

  refined="$(run_ollama "${prompt}" || true)"
  if [[ -n "${refined}" ]]; then
    result="${refined}"
    label="Ollama ${mode} output"
  fi
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
{
  printf '%s\n%s\n\n%s\n%s\n' "--- raw ---" "${text}" "--- result (${label}) ---" "${result}"
} >"${state_dir}/${timestamp}.txt"

printf '%s\n' "${result}" | wl-copy
preview="$(printf '%s\n' "${result}" | head -c 240)"
lumina-toast "OCR" "Copied ${label} to clipboard: ${preview}" success 2>/dev/null || true
