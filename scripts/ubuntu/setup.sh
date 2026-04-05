#!/bin/bash
# =============================================================
#  Ubuntu Setup Script — Development
#  Usage: bash scripts/ubuntu/setup.sh
#  or:    curl -sL https://raw.githubusercontent.com/CuB1z/setup/main/scripts/ubuntu/setup.sh | bash
# =============================================================

set -e
GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
step() { echo -e "\n${CYAN}== $1 ==${NC}"; }
ok()   { echo -e "${GREEN}[OK] $1${NC}"; }
warn() { echo -e "${YELLOW}[!] $1${NC}"; }

# ── System update ─────────────────────────────────────────────
step "Updating system"
sudo apt update && sudo apt upgrade -y

# ── Base tools ────────────────────────────────────────────────
step "Installing base tools"
sudo apt install -y \
  git curl wget build-essential unzip ca-certificates gnupg lsb-release \
  stow xclip xsel fontconfig fzf tmux ripgrep bat eza

# bat may be called batcat on Ubuntu
if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
  mkdir -p ~/.local/bin
  ln -sf "$(which batcat)" ~/.local/bin/bat
fi
ok "Base tools installed"

# ── FiraCode Nerd Font ────────────────────────────────────────
step "FiraCode Nerd Font"
FONT_DIR="$HOME/.local/share/fonts/NerdFonts"
mkdir -p "$FONT_DIR"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
curl -fLo /tmp/FiraCode.zip "$FONT_URL"
unzip -o /tmp/FiraCode.zip -d "$FONT_DIR" '*.ttf' 2>/dev/null || true
fc-cache -fv "$FONT_DIR" > /dev/null
ok "FiraCode Nerd Font installed — set your terminal to use it"

# ── Brave Browser ─────────────────────────────────────────────
step "Brave Browser"
curl -fsS https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg | \
  sudo tee /usr/share/keyrings/brave-browser-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] \
https://brave-browser-apt-release.s3.brave.com/ stable main" | \
  sudo tee /etc/apt/sources.list.d/brave-browser-release.list
sudo apt update && sudo apt install -y brave-browser
ok "Brave installed"

# ── Brave extensions (via managed policy) ────────────────────
step "Brave extensions"
BRAVE_POLICY_DIR="/etc/opt/chrome/policies/managed"
sudo mkdir -p "$BRAVE_POLICY_DIR"

sudo tee "$BRAVE_POLICY_DIR/extensions.json" > /dev/null << 'EOF'
{
  "ExtensionInstallForcelist": [
    "nngceckbapebfimnlniiiahkandclblb;https://clients2.google.com/service/update2/crx",
    "lpcaedmchfhocbbapmcbpinfpgnhiddi;https://clients2.google.com/service/update2/crx",
    "eimadpbcbfnmbkopoojfekhnkhdbieeh;https://clients2.google.com/service/update2/crx"
  ]
}
EOF
# nngceckbapebfimnlniiiahkandclblb = Bitwarden
# lpcaedmchfhocbbapmcbpinfpgnhiddi = Material Icons for GitHub
# eimadpbcbfnmbkopoojfekhnkhdbieeh = Markdown Viewer

warn "Extensions configured via policy — they install automatically when Brave opens."
ok "Brave extension policy created"

# ── Brave bookmarks ───────────────────────────────────────────
step "Brave bookmarks"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/brave_bookmarks.html" ]; then
  warn "brave_bookmarks.html found — import it manually via brave://bookmarks → Import"
else
  warn "To export your bookmarks: Brave → brave://bookmarks → ⋮ → Export bookmarks"
  warn "Save the .html file as ubuntu/brave_bookmarks.html in your repo"
fi

# ── Docker + Docker Compose ───────────────────────────────────
step "Docker + Docker Compose"
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker "$USER"
ok "Docker installed (logout required to use without sudo)"

# ── Visual Studio Code ────────────────────────────────────────
step "Visual Studio Code"
sudo snap install code --classic
sleep 3

VSCODE_EXTENSIONS=(
  "zhuangtongfa.material-theme"
  "miguelsolorio.fluent-icons"
  "pkief.material-icon-theme"
  "usernamehw.errorlens"
  "mhutchie.git-graph"
  "eamodio.gitlens"
  "ms-python.python"
  "vscjava.vscode-java-pack"
  "vmware.vscode-boot-dev-pack"
  "ms-azuretools.vscode-docker"
  "vitest.explorer" 
)

step "Installing VSCode extensions"
for ext in "${VSCODE_EXTENSIONS[@]}"; do
  code --install-extension "$ext" --force 2>/dev/null || warn "Could not install: $ext"
done
ok "VSCode extensions installed"

# VSCode settings.json
VSCODE_SETTINGS_DIR="$HOME/.config/Code/User"
mkdir -p "$VSCODE_SETTINGS_DIR"
cat > "$VSCODE_SETTINGS_DIR/settings.json" << 'EOF'
{
  "editor.fontFamily": "'FiraCode Nerd Font', 'Fira Code', monospace",
  "editor.fontLigatures": true,
  "editor.fontSize": 14,
  "editor.lineHeight": 1.6,
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.tabSize": 2,
  "editor.minimap.enabled": false,
  "editor.bracketPairColorization.enabled": true,
  "editor.guides.bracketPairs": true,
  "editor.stickyScroll.enabled": true,
  "editor.rulers": [100],
  "editor.renderWhitespace": "boundary",
  "editor.smoothScrolling": true,
  "editor.cursorBlinking": "expand",
  "editor.cursorSmoothCaretAnimation": "on",
  "editor.cursorWidth": 2,
  "editor.links": false,
  "editor.detectIndentation": false,
  "editor.inlineSuggest.enabled": true,

  "workbench.iconTheme": "material-icon-theme",
  "workbench.colorTheme": "One Dark Pro Mix",
  "workbench.productIconTheme": "fluent-icons",
  "workbench.activityBar.location": "top",
  "workbench.sideBar.location": "right",
  "workbench.startupEditor": "none",
  "workbench.tree.enableStickyScroll": false,
  "workbench.tree.renderIndentGuides": "none",
  "workbench.tree.indent": 8,
  "workbench.panel.showLabels": false,
  "window.menuBarVisibility": "compact",
  "workbench.layoutControl.enabled": false,
  "window.commandCenter": false,
  "window.zoomLevel": 1,

  "terminal.integrated.fontFamily": "'FiraCode Nerd Font'",
  "terminal.integrated.fontSize": 13,
  "terminal.integrated.fontLigatures.enabled": true,

  "files.autoSave": "onFocusChange",
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true,
  "files.associations": {
    "*.css": "scss"
  },
  "files.exclude": {
    "**/.git": true,
    "**/node_modules": true,
    "**/target": true
  },

  "explorer.confirmDelete": false,
  "explorer.confirmDragAndDrop": false,
  "explorer.confirmPasteNative": false,
  "explorer.decorations.badges": false,

  "git.enableSmartCommit": true,
  "git.confirmSync": false,
  "git.autofetch": true,
  "js/ts.updateImportsOnFileMove.enabled": "always",

  "prettier.singleQuote": true,
  "prettier.semi": true,
  "prettier.printWidth": 100,
  "prettier.trailingComma": "es5",
  "diffEditor.ignoreTrimWhitespace": false,
  "gitlens.ai.model": "vscode",
  "gitlens.ai.vscode.model": "copilot:gpt-4.1",

  "[java]": {
    "editor.defaultFormatter": "redhat.java",
    "editor.tabSize": 4
  },
  "[python]": {
    "editor.defaultFormatter": "ms-python.python",
    "editor.tabSize": 4
  },

  "extensions.ignoreRecommendations": true,
  "telemetry.telemetryLevel": "off",
  "update.mode": "start",
  "security.workspace.trust.untrustedFiles": "open",
  "http.systemCertificatesNode": true,
  "chat.viewSessions.orientation": "stacked"
}
EOF
ok "VSCode configured"

# ── Postman ───────────────────────────────────────────────────
step "Postman"
sudo snap install postman
ok "Postman installed"

# ── Spotify ───────────────────────────────────────────────────
step "Spotify"
sudo snap install spotify
ok "Spotify installed"

# ── Obsidian ──────────────────────────────────────────────────
step "Obsidian"
sudo snap install obsidian --classic
ok "Obsidian installed"

# ── nvm + Node LTS (latest stable) ───────────────────────────
step "nvm + Node.js LTS"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm alias default 'lts/*'
npm install -g pnpm
ok "Node LTS $(node -v) installed via nvm"

# ── pyenv + Python (latest stable) ───────────────────────────
step "pyenv + Python"
sudo apt install -y make libssl-dev libffi-dev zlib1g-dev libbz2-dev \
  libreadline-dev libsqlite3-dev libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev
curl https://pyenv.run | bash
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
LATEST_PYTHON=$(pyenv install --list | grep -E "^\s+3\.[0-9]+\.[0-9]+$" | tail -1 | tr -d ' ')
pyenv install "$LATEST_PYTHON"
pyenv global "$LATEST_PYTHON"
ok "Python $LATEST_PYTHON installed via pyenv"

# ── SDKMAN + Java LTS ─────────────────────────────────────────
step "SDKMAN + Java LTS"
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh" 2>/dev/null || true
sdk install java $(sdk list java | grep -E "tem.*21\." | head -1 | awk '{print $NF}') || \
sdk install java 21.0.3-tem
sdk default java 21.0.3-tem 2>/dev/null || true
ok "Java LTS installed via SDKMAN"

# ── OpenCode ──────────────────────────────────────────────────
step "OpenCode"
curl -fsSL https://opencode.ai/install | bash && ok "OpenCode installed" || \
  warn "Install OpenCode manually: curl -fsSL https://opencode.ai/install | bash"

# ── Git global config ─────────────────────────────────────────
step "Git global configuration"
echo -n "  Your name for Git (e.g. John Smith): "
read -r GIT_NAME
echo -n "  Your email for Git (e.g. john@email.com): "
read -r GIT_EMAIL

git config --global user.name  "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.editor "code --wait"
git config --global core.autocrlf input

cat > "$HOME/.gitignore_global" << 'EOF'
# OS
.DS_Store
Thumbs.db
.Spotlight-V100
.Trashes

# Environment & secrets
.env
.env.local
.env.*.local
*.pem
*.key

# Dependencies
node_modules/
vendor/
.venv/
__pycache__/
*.pyc

# Build output
dist/
build/
out/
target/
*.class
*.jar

# IDE
.vscode/
.idea/
*.iml
*.suo
*.user
.project
.classpath
.settings/

# Logs
*.log
npm-debug.log*
EOF

git config --global core.excludesfile "$HOME/.gitignore_global"
ok "Git configured for $GIT_NAME <$GIT_EMAIL>"

# ── fzf shell integration ─────────────────────────────────────
step "fzf shell integration"
# fzf already installed via apt — shell integrations added in .bashrc below
ok "fzf ready"

# ── tmux config ───────────────────────────────────────────────
step "tmux configuration"
cat > "$HOME/.tmux.conf" << 'EOF'
# =============================================================
#  tmux.conf — Beginner-friendly config
#
#  QUICK REFERENCE:
#    Prefix:              Ctrl+a  (changed from Ctrl+b)
#    New window:          Prefix + c
#    Next / prev window:  Prefix + n / p
#    List windows:        Prefix + w
#    Split vertical:      Prefix + |
#    Split horizontal:    Prefix + -
#    Move between panes:  Prefix + h/j/k/l  (or arrow keys)
#    Close pane:          Prefix + x
#    Detach session:      Prefix + d
#    Reattach:            tmux attach
#    New named session:   tmux new -s name
#    List sessions:       tmux ls
#    Reload config:       Prefix + r
# =============================================================

# Change prefix to Ctrl+a (more ergonomic than Ctrl+b)
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Intuitive splits with | and -
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

# Navigate panes with h/j/k/l (vim-style)
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Resize panes with H/J/K/L
bind H resize-pane -L 5
bind J resize-pane -D 5
bind K resize-pane -U 5
bind L resize-pane -R 5

# Reload config with Prefix + r
bind r source-file ~/.tmux.conf \; display "Config reloaded"

# New window opens in current directory
bind c new-window -c "#{pane_current_path}"

# Start window/pane numbering at 1 (easier to reach on keyboard)
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on

# Enable mouse (scroll, click to select pane)
set -g mouse on

# Larger scrollback history
set -g history-limit 10000

# No escape delay (better for vim/neovim)
set -s escape-time 10

# 256 color support
set -g default-terminal "screen-256color"
set -ga terminal-overrides ",xterm-256color:Tc"

# Status bar
set -g status-position bottom
set -g status-bg colour234
set -g status-fg colour137
set -g status-left ' #[fg=colour39]#S '
set -g status-right '#[fg=colour233,bg=colour241] %d/%m #[fg=colour233,bg=colour245] %H:%M '
set -g status-right-length 50
set -g status-left-length 20
setw -g window-status-current-format ' #I:#W#[fg=colour50]* '
setw -g window-status-format ' #I:#W '
EOF
ok "tmux configured — quick reference is in the comments at ~/.tmux.conf"

# ── Bash shell profile ───────────────────────────────────────
step "Writing Bash shell profile"
BASHRC_FILE="$HOME/.bashrc"
BASHRC_START="# >>> setup.sh managed block >>>"
BASHRC_END="# <<< setup.sh managed block <<<"

touch "$BASHRC_FILE"
awk -v start="$BASHRC_START" -v end="$BASHRC_END" '
  $0 == start { in_block = 1; next }
  $0 == end { in_block = 0; next }
  !in_block { print }
' "$BASHRC_FILE" > "$BASHRC_FILE.tmp" && mv "$BASHRC_FILE.tmp" "$BASHRC_FILE"

cat >> "$BASHRC_FILE" << 'BASHRC'
# >>> setup.sh managed block >>>

# ── nvm ────────────────────────────────────────────────────
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# ── pyenv ──────────────────────────────────────────────────
export PYENV_ROOT="$HOME/.pyenv"
[ -d "$PYENV_ROOT/bin" ] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# ── SDKMAN ─────────────────────────────────────────────────
export SDKMAN_DIR="$HOME/.sdkman"
[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && . "$SDKMAN_DIR/bin/sdkman-init.sh"

# ── fzf ────────────────────────────────────────────────────
# Ctrl+R: fuzzy history search | Ctrl+T: fuzzy file search
[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && . /usr/share/doc/fzf/examples/key-bindings.bash
[ -f /usr/share/doc/fzf/examples/completion.bash ] && . /usr/share/doc/fzf/examples/completion.bash
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"
export FZF_DEFAULT_COMMAND='find . -type f -not -path "*/node_modules/*" -not -path "*/.git/*"'

# ── PATH & env ─────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"
export EDITOR=code
export TERM=xterm-256color

# ── Aliases: git ───────────────────────────────────────────
alias gs="git status"
alias ga="git add"
alias gc="git commit -m"
alias gp="git push"
alias gpl="git pull"
alias gco="git checkout"
alias gcb="git checkout -b"
alias gl="git log --oneline --graph --decorate"
alias gd="git diff"

# ── Aliases: docker ────────────────────────────────────────
alias dc="docker compose"
alias dcu="docker compose up -d"
alias dcd="docker compose down"
alias dps="docker ps"
alias dlogs="docker compose logs -f"

# ── Aliases: navigation ────────────────────────────────────
alias ll="eza -la --icons --git"
alias lt="eza --tree --icons -L 2"
alias cat="bat --style=auto"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias grep="rg"

# ── Aliases: dev ───────────────────────────────────────────
alias nrd="npm run dev"
alias nrb="npm run build"
alias nrt="npm run test"
alias py="python3"
alias pip="pip3"

# ── Function: new-ssh ──────────────────────────────────────
# Generates an ed25519 SSH key and copies the public key to clipboard
# Usage: new-ssh              (uses email from git config)
#        new-ssh work         (creates id_ed25519_work)
#        new-ssh work me@x.com
new-ssh() {
  local label="${1:-}"
  local email="${2:-$(git config --global user.email)}"
  [ -z "$email" ] && { echo "Usage: new-ssh [label] [email]"; return 1; }
  [ -z "$label" ] && label=$(echo "$email" | cut -d@ -f1)
  local keypath="$HOME/.ssh/id_ed25519_$label"

  echo "Generating SSH key: $keypath"
  ssh-keygen -t ed25519 -C "$email" -f "$keypath"

  # Add to ssh-agent
  eval "$(ssh-agent -s)"
  ssh-add "$keypath"

  # Add entry to ~/.ssh/config
  cat >> "$HOME/.ssh/config" << EOF

Host github-$label
  HostName github.com
  User git
  IdentityFile $keypath
EOF

  echo ""
  echo "Public key (paste in GitHub / GitLab -> Settings -> SSH keys):"
  echo "──────────────────────────────────────────────────────────────"
  cat "${keypath}.pub"
  echo "──────────────────────────────────────────────────────────────"
  cat "${keypath}.pub" | xclip -selection clipboard 2>/dev/null || \
  cat "${keypath}.pub" | xsel --clipboard --input 2>/dev/null || true
  echo "[OK] Copied to clipboard"
  echo ""
  echo "Test the connection with: ssh -T git@github.com"
}

# ── Function: update-all ──────────────────────────────────
# Updates system, Node, Python and Java in one command
update-all() {
  echo "== Updating system =="
  sudo apt update && sudo apt upgrade -y

  echo "== Updating Node to latest LTS =="
  nvm install --lts && nvm alias default 'lts/*'

  echo "== Updating Python to latest stable =="
  LATEST_PY=$(pyenv install --list | grep -E "^\s+3\.[0-9]+\.[0-9]+$" | tail -1 | tr -d ' ')
  pyenv install "$LATEST_PY" --skip-existing
  pyenv global "$LATEST_PY"

  echo "== Updating Java LTS via SDKMAN =="
  sdk selfupdate
  sdk update

  echo "== Updating global npm packages =="
  npm update -g

  echo "[OK] Everything updated"
}

# <<< setup.sh managed block <<<
BASHRC

ok "Bash profile updated in ~/.bashrc"

# ── SSH permissions ───────────────────────────────────────────
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
touch "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config"

# ── Done ──────────────────────────────────────────────────────
echo -e "\n${GREEN}============================================${NC}"
echo -e "${GREEN}  Setup complete. Final steps:${NC}"
echo -e "  1. Close and reopen terminal (or: exec bash)"
echo -e "  2. ${CYAN}new-ssh${NC} — generate your SSH key and copy it to GitHub"
echo -e "  3. ${CYAN}sdk install java${NC} — if auto-install failed"
echo -e "  4. ${CYAN}update-all${NC} — to update everything in the future"
echo -e "  5. Open Brave and verify Bitwarden installed"
echo -e "  6. Set your terminal font to ${CYAN}FiraCode Nerd Font${NC}"
echo -e "  7. Read ${CYAN}~/.tmux.conf${NC} for the tmux quick reference"
echo -e "  8. Restart so Docker works without sudo"
echo -e "${GREEN}============================================${NC}\n"
