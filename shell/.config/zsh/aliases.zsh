# vim: ft=zsh
# shell/.config/zsh/aliases.zsh
# Comprehensive Zsh aliases for lumina-merged
# Sourced by ~/.zshrc

# ─── Safety ───────────────────────────────────────────────────────────────────
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias mkdir='mkdir -p'

# ─── Navigation ───────────────────────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'

# ─── Listing ──────────────────────────────────────────────────────────────────
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza --icons -lahF --group-directories-first --git'
  alias la='eza --icons -lAhF --group-directories-first --git'
  alias lt='eza --icons --tree --level=2'
  alias lS='eza --icons -lahFS --group-directories-first'
else
  alias ls='ls --color=auto --group-directories-first'
  alias ll='ls -lahF --color=auto --group-directories-first'
  alias la='ls -lAhF --color=auto --group-directories-first'
  alias lt='ls -lahFt --color=auto'
  alias lS='ls -lahFS --color=auto'
fi

# ─── Editors ──────────────────────────────────────────────────────────────────
alias v='nvim'
alias vi='nvim'
alias vim='nvim'

# ─── Git ──────────────────────────────────────────────────────────────────────
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gaa='git add -A'
alias gcm='git commit -m'
alias gp='git push'
alias gpl='git pull'
alias gl='git log --oneline --graph --decorate --color=always | head -20'
alias gd='git diff'
alias gds='git diff --staged'
alias gb='git branch -vv'
alias gco='git checkout'
alias gcb='git checkout -b'

# ─── Package management ───────────────────────────────────────────────────────
alias pacs='sudo pacman -S'
alias pacr='sudo pacman -Rns'
alias pacu='sudo pacman -Syu'
alias pacq='pacman -Qi'
alias parui='paru -S'
alias paruu='paru -Su --aur'

# ─── System ───────────────────────────────────────────────────────────────────
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias bt='btop'
alias htop='btop'
alias psg='ps auxf | grep -v grep | grep -i'
alias ports='ss -tulnp'

# ─── Systemd ──────────────────────────────────────────────────────────────────
alias sstart='sudo systemctl start'
alias sstop='sudo systemctl stop'
alias srestart='sudo systemctl restart'
alias sstatus='systemctl status'
alias senable='sudo systemctl enable --now'
alias sdisable='sudo systemctl disable --now'
alias ustart='systemctl --user start'
alias ustop='systemctl --user stop'
alias urestart='systemctl --user restart'
alias ustatus='systemctl --user status'

# ─── Dotfiles ─────────────────────────────────────────────────────────────────
alias dots='dotfiles'
alias theme='dotfiles theme'
alias doctor='dotfiles doctor'
alias wallset='dotfiles theme'

# ─── Hyprland ─────────────────────────────────────────────────────────────────
alias hreload='hyprctl reload'
alias hkill='hyprctl kill'
alias hmonitors='hyprctl monitors'
alias hclients='hyprctl clients'
alias hpanel='pkill -x hyprpanel 2>/dev/null; while pgrep -x hyprpanel >/dev/null; do sleep 0.1; done; hyprpanel &>/dev/null & disown'

# ─── Misc ─────────────────────────────────────────────────────────────────────
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias less='less -R'
if command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never'
  alias catp='bat'
fi
if command -v fd >/dev/null 2>&1; then
  alias find='fd'
fi
alias path='echo -e "${PATH//:/\\n}"'
alias reload='source ~/.zshrc && echo "Zshrc reloaded"'
alias c='clear'
alias myip='curl -s https://api.ipify.org && echo'
alias weather='curl -s "wttr.in/?format=3"'
