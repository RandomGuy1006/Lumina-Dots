# shell/.config/zsh/functions.zsh
# Zsh utility functions for lumina-merged

# ─── Yazi with cwd sync ───────────────────────────────────────────────────────
# Launch yazi and cd to its last directory on exit
y() {
  local tmp cwd
  tmp="$(mktemp -t yazi-cwd.XXXXXX)"
  yazi "$@" --cwd-file="${tmp}"
  if cwd="$(cat "${tmp}")" && [[ -n "${cwd}" ]] && [[ "${cwd}" != "${PWD}" ]]; then
    cd "${cwd}"
  fi
  rm -f "${tmp}"
}

# ─── mkdir + cd ───────────────────────────────────────────────────────────────
mkcd() {
  mkdir -p "$1" && cd "$1"
}

# ─── Archive extraction ───────────────────────────────────────────────────────
extract() {
  if [[ ! -f "$1" ]]; then
    echo "$1 is not a valid file"
    return 1
  fi
  case "$1" in
    *.tar.bz2)   tar xjf "$1"     ;;
    *.tar.gz)    tar xzf "$1"     ;;
    *.tar.xz)    tar xJf "$1"     ;;
    *.tar.zst)   tar --zstd -xf "$1" ;;
    *.bz2)       bunzip2 "$1"     ;;
    *.rar)       unrar x "$1"     ;;
    *.gz)        gunzip "$1"      ;;
    *.tar)       tar xf "$1"      ;;
    *.tbz2)      tar xjf "$1"     ;;
    *.tgz)       tar xzf "$1"     ;;
    *.zip)       unzip "$1"       ;;
    *.7z)        7z x "$1"        ;;
    *.zst)       zstd -d "$1"     ;;
    *)           echo "Cannot extract: $1" && return 1 ;;
  esac
}

# ─── Quick process kill ───────────────────────────────────────────────────────
fkill() {
  local pid
  pid=$(ps aux | fzf --header='[kill process]' | awk '{print $2}')
  [[ -n "${pid}" ]] && kill -9 "${pid}"
}

# ─── Open in Neovim with fzf ─────────────────────────────────────────────────
vf() {
  local file
  file=$(find . -type f | fzf --preview 'bat --color=always --style=numbers {}') && nvim "${file}"
}

# ─── cd with fzf ─────────────────────────────────────────────────────────────
cdf() {
  local dir
  dir=$(find . -type d | fzf --preview 'ls -la {}') && cd "${dir}"
}

# ─── dotfiles-aware cd ────────────────────────────────────────────────────────
dots-cd() {
  local hypr_conf="${HOME}/.config/hypr/hyprland.conf"
  if [[ -L "${hypr_conf}" ]]; then
    local dots_dir
    dots_dir="$(dirname "$(dirname "$(dirname "$(dirname "$(realpath "${hypr_conf}")")")")")"
    cd "${dots_dir}"
  else
    echo "lumina-merged not linked — check dotfiles install"
  fi
}

# ─── Quick system info ────────────────────────────────────────────────────────
sysinfo() {
  echo "  OS:      $(uname -r)"
  echo "  Uptime:  $(uptime -p)"
  echo "  Memory:  $(free -h | awk '/^Mem/{print $3 " / " $2}')"
  echo "  Disk:    $(df -h / | awk 'NR==2{print $3 " / " $2 " (" $5 ")"}')"
  echo "  CPU:     $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
  command -v Hyprland &>/dev/null && echo "  Hypr:    $(Hyprland --version 2>/dev/null || echo 'installed')"
}

# ─── Cleanup old kernels ──────────────────────────────────────────────────────
cleanup-kernels() {
  local current
  current="$(uname -r)"
  echo "Current kernel: ${current}"
  pacman -Q | grep -E '^linux(-lts|-zen|-hardened|-rt)?[[:space:]]' | while read -r pkg ver; do
    if [[ "${current}" == *"${ver}"* ]]; then
      echo "Keeping (running): ${pkg}"
    else
      echo "Removing: ${pkg}"
      sudo pacman -Rns --noconfirm "${pkg}"
    fi
  done
}
