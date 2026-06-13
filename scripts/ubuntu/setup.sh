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
  stow xclip xsel wl-clipboard fontconfig fzf ripgrep bat eza apt-transport-https

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
BRAVE_POLICY_DIR="/etc/brave/policies/managed"
sudo mkdir -p "$BRAVE_POLICY_DIR"

sudo tee "$BRAVE_POLICY_DIR/extensions.json" > /dev/null << 'EOF'
{
  "ExtensionInstallForcelist": [
    "nngceckbapebfimnlniiiahkandclblb;https://clients2.google.com/service/update2/crx",
    "bggfcpfjbdkhfhfmkjpbhnkhnpjjeomc;https://clients2.google.com/service/update2/crx",
    "ckkdlimhmcjmikdlpkmbgfkaikojcbjk;https://clients2.google.com/service/update2/crx"
  ]
}
EOF
# nngceckbapebfimnlniiiahkandclblb = Bitwarden
# bggfcpfjbdkhfhfmkjpbhnkhnpjjeomc = Material Icons for GitHub
# ckkdlimhmcjmikdlpkmbgfkaikojcbjk = Markdown Viewer

warn "Extensions configured via policy — they install automatically when Brave opens."
ok "Brave extension policy created"

# ── Brave bookmarks ───────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/brave_bookmarks.html" ]; then
  step "Brave bookmarks"
  warn "brave_bookmarks.html found — import it manually via brave://bookmarks → Import"
fi

# ── Docker + Docker Compose ───────────────────────────────────
step "Docker + Docker Compose"
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker "$USER"
ok "Docker installed (logout required to use without sudo)"

# ── Visual Studio Code ────────────────────────────────────────
step "Visual Studio Code"
curl -fsS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | \
  sudo tee /usr/share/keyrings/packages.microsoft.gpg > /dev/null
echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/packages.microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" | \
  sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
sudo apt update && sudo apt install -y code

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
snap list postman &>/dev/null || sudo snap install postman
ok "Postman installed"

# ── Spotify ───────────────────────────────────────────────────
step "Spotify"
snap list spotify &>/dev/null || sudo snap install spotify
ok "Spotify installed"

# ── Discord ───────────────────────────────────────────────────
step "Discord"
snap list discord &>/dev/null || sudo snap install discord
ok "Discord installed"

# ── Obsidian ──────────────────────────────────────────────────
step "Obsidian"
snap list obsidian &>/dev/null || sudo snap install obsidian --classic
ok "Obsidian installed"

# ── DBeaver Community ─────────────────────────────────────────
step "DBeaver"
snap list dbeaver-ce &>/dev/null || sudo snap install dbeaver-ce
ok "DBeaver installed"

# ── Terminator ────────────────────────────────────────────────
step "Terminator"
sudo apt install -y terminator
mkdir -p "$HOME/.config/terminator"
cat > "$HOME/.config/terminator/config" << 'EOF'
[global_config]
  handle_size = 0
  inactive_color_offset = 0.6527777777777778
  ask_before_closing = never
[keybindings]
[profiles]
  [[default]]
    cursor_shape = ibeam
    cursor_fg_color = "#000000"
    cursor_bg_color = "#aaaaaa"
    show_titlebar = False
    use_system_font = False
    font = FiraCode Nerd Font 12
    palette = "#282828:#cc241d:#a9a81d:#d79921:#419a9e:#b16286:#689d6a:#a89984:#928374:#fb4934:#d1ec31:#fabd2f:#8bd5d7:#d3869b:#8ec07c:#ebdbb2"
    use_theme_colors = True
    bold_is_bright = True
[layouts]
  [[default]]
    [[[window0]]]
      type = Window
      parent = ""
    [[[child1]]]
      type = Terminal
      parent = window0
[plugins]
EOF
ok "Terminator installed and configured (clean theme + FiraCode Nerd Font)"

# ── nvm + Node LTS (latest stable) ───────────────────────────
step "nvm + Node.js LTS"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
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
[ -d "$HOME/.pyenv" ] || curl https://pyenv.run | bash
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
LATEST_PYTHON=$(pyenv install --list | grep -E "^\s+3\.[0-9]+\.[0-9]+$" | tail -1 | tr -d ' ')
pyenv install -s "$LATEST_PYTHON"
pyenv global "$LATEST_PYTHON"
ok "Python $LATEST_PYTHON installed via pyenv"

# ── SDKMAN + Java LTS ─────────────────────────────────────────
step "SDKMAN + Java LTS"
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh" 2>/dev/null || true
JAVA_VERSION=$(sdk list java 2>/dev/null | grep -oE '21\.[0-9]+\.[0-9]+-tem' | head -1)
[ -z "$JAVA_VERSION" ] && JAVA_VERSION="21.0.3-tem"
sdk install java "$JAVA_VERSION" || true
sdk default java "$JAVA_VERSION" 2>/dev/null || true
ok "Java $JAVA_VERSION installed via SDKMAN"

# ── OpenCode ──────────────────────────────────────────────────
step "OpenCode"
curl -fsSL https://opencode.ai/install | bash && ok "OpenCode installed" || \
  warn "Install OpenCode manually: curl -fsSL https://opencode.ai/install | bash"

# ── GitHub CLI ────────────────────────────────────────────────
step "GitHub CLI"
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
  sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
https://cli.github.com/packages stable main" | \
  sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install -y gh
ok "GitHub CLI installed (run 'gh auth login' to authenticate)"

# ── Timezone & locale ─────────────────────────────────────────
step "Timezone (Europe/Madrid)"
sudo timedatectl set-timezone Europe/Madrid 2>/dev/null || warn "Could not set timezone"
ok "Timezone set"

# ── Unattended security upgrades ──────────────────────────────
step "Unattended security upgrades"
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -f noninteractive unattended-upgrades
ok "Automatic security upgrades enabled"

# ── Git global config ─────────────────────────────────────────
step "Git global configuration"
# Allow env var override for non-interactive (curl | bash) runs.
# When piped, stdin is the script, so we read from /dev/tty.
if [ -z "${GIT_NAME:-}" ]; then
  echo -n "  Your name for Git (e.g. John Smith): "
  read -r GIT_NAME </dev/tty || true
fi
if [ -z "${GIT_EMAIL:-}" ]; then
  echo -n "  Your email for Git (e.g. john@email.com): "
  read -r GIT_EMAIL </dev/tty || true
fi

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
alias rgg="rg"

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

  # Add entry to ~/.ssh/config (skip if already present)
  if ! grep -q "^Host github-$label$" "$HOME/.ssh/config" 2>/dev/null; then
    cat >> "$HOME/.ssh/config" << EOF

Host github-$label
  HostName github.com
  User git
  IdentityFile $keypath
EOF
  fi

  echo ""
  echo "Public key (paste in GitHub / GitLab -> Settings -> SSH keys):"
  echo "──────────────────────────────────────────────────────────────"
  cat "${keypath}.pub"
  echo "──────────────────────────────────────────────────────────────"
  # Wayland first, then X11 fallbacks
  if command -v wl-copy &>/dev/null && [ -n "$WAYLAND_DISPLAY" ]; then
    wl-copy < "${keypath}.pub"
  elif command -v xclip &>/dev/null; then
    xclip -selection clipboard < "${keypath}.pub"
  elif command -v xsel &>/dev/null; then
    xsel --clipboard --input < "${keypath}.pub"
  fi
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
  command -v pnpm &>/dev/null && pnpm self-update 2>/dev/null || true

  echo "== Updating OpenCode =="
  command -v opencode &>/dev/null && (curl -fsSL https://opencode.ai/install | bash) || true

  echo "== Cleaning up apt =="
  sudo apt autoremove -y && sudo apt autoclean -y

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

# ── GNOME Shell Extension Manager ─────────────────────────────
step "GNOME Shell Extension Manager"
sudo apt install -y gnome-shell-extension-manager
ok "gnome-shell-extension-manager installed"

# ── GNOME Shell extensions ────────────────────────────────────
step "GNOME Shell extensions"
install_gnome_extension() {
  local uuid="$1"
  if ! command -v gnome-shell &>/dev/null || ! command -v gnome-extensions &>/dev/null; then
    warn "GNOME Shell not available — skipping $uuid"
    return 0
  fi
  local shell_version
  shell_version=$(gnome-shell --version | grep -oE '[0-9]+' | head -1)
  local info
  info=$(curl -fsS "https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${shell_version}" 2>/dev/null) || {
    warn "Could not query extensions.gnome.org for $uuid"
    return 0
  }
  local version_tag
  version_tag=$(echo "$info" | grep -oE '"version_tag":[[:space:]]*[0-9]+' | grep -oE '[0-9]+$' | head -1)
  if [ -z "$version_tag" ]; then
    warn "No compatible version of $uuid for GNOME $shell_version"
    return 0
  fi
  local tmp
  tmp=$(mktemp -d)
  if curl -fsSL "https://extensions.gnome.org/download-extension/${uuid}.shell-extension.zip?version_tag=${version_tag}" -o "$tmp/ext.zip"; then
    gnome-extensions install -f "$tmp/ext.zip" 2>/dev/null || warn "Failed to install $uuid"
    gnome-extensions enable "$uuid" 2>/dev/null || warn "Enable $uuid after restarting GNOME Shell"
    ok "Installed $uuid"
  else
    warn "Could not download $uuid"
  fi
  rm -rf "$tmp"
}

GNOME_EXTENSIONS=(
  "space-bar@luchrioh"
)
for ext in "${GNOME_EXTENSIONS[@]}"; do
  install_gnome_extension "$ext"
done
warn "Log out and back in (or restart GNOME Shell) to fully activate extensions"

# ── GNOME tweaks ──────────────────────────────────────────────
step "GNOME tweaks"
if command -v gsettings &>/dev/null && [ -n "${XDG_CURRENT_DESKTOP:-}" ]; then
  # Dark mode
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true
  # Top-bar clock: date (month + day) and 24h time — no weekday, no seconds
  gsettings set org.gnome.desktop.interface clock-show-date true 2>/dev/null || true
  gsettings set org.gnome.desktop.interface clock-show-weekday false 2>/dev/null || true
  gsettings set org.gnome.desktop.interface clock-show-seconds false 2>/dev/null || true
  gsettings set org.gnome.desktop.interface clock-format '24h' 2>/dev/null || true
  # Disable natural scroll on mouse (keep on touchpad)
  gsettings set org.gnome.desktop.peripherals.mouse natural-scroll false 2>/dev/null || true

  # Spanish keyboard layout
  gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'es')]" 2>/dev/null || true

  # Desktop background — copy local asset, or download it (curl|bash runs have no local repo)
  BG_DEST="$HOME/Pictures/background.jpg"
  mkdir -p "$HOME/Pictures"
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)"
  BG_SRC="$REPO_ROOT/assets/background.jpg"
  if [ -f "$BG_SRC" ]; then
    cp "$BG_SRC" "$BG_DEST"
  else
    curl -fsSL "https://raw.githubusercontent.com/CuB1z/setup/main/assets/background.jpg" \
      -o "$BG_DEST" 2>/dev/null || warn "Could not download desktop background"
  fi
  if [ -f "$BG_DEST" ]; then
    gsettings set org.gnome.desktop.background picture-uri "file://$BG_DEST" 2>/dev/null || true
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$BG_DEST" 2>/dev/null || true
    gsettings set org.gnome.desktop.background picture-options 'zoom' 2>/dev/null || true
  fi

  # Fixed 4 workspaces (disable dynamic) + Super+1..4 to switch
  gsettings set org.gnome.mutter dynamic-workspaces false 2>/dev/null || true
  gsettings set org.gnome.desktop.wm.preferences num-workspaces 4 2>/dev/null || true
  for i in 1 2 3 4; do
    gsettings set org.gnome.desktop.wm.keybindings "switch-to-workspace-$i" "['<Super>$i']" 2>/dev/null || true
    gsettings set org.gnome.shell.keybindings "switch-to-application-$i" "[]" 2>/dev/null || true
  done
  # Ubuntu Dock intercepts Super+N to launch dock apps — disable so workspace shortcuts win
  gsettings set org.gnome.shell.extensions.dash-to-dock hot-keys false 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.dash-to-dock shortcut "[]" 2>/dev/null || true

  # ── Ubuntu Dock layout (position, size, behaviour) ────────
  DOCK=org.gnome.shell.extensions.dash-to-dock
  gsettings set $DOCK dock-position 'BOTTOM' 2>/dev/null || true       # bottom of the screen
  gsettings set $DOCK extend-height false 2>/dev/null || true          # centred floating dock, not full-width panel
  gsettings set $DOCK dock-fixed false 2>/dev/null || true             # let it hide
  gsettings set $DOCK autohide true 2>/dev/null || true
  gsettings set $DOCK intellihide true 2>/dev/null || true             # only hide when a window overlaps it
  gsettings set $DOCK intellihide-mode 'ALL_WINDOWS' 2>/dev/null || true
  gsettings set $DOCK dash-max-icon-size 28 2>/dev/null || true        # compact icons
  gsettings set $DOCK icon-size-fixed true 2>/dev/null || true
  gsettings set $DOCK show-trash false 2>/dev/null || true
  gsettings set $DOCK show-mounts false 2>/dev/null || true
  gsettings set $DOCK show-apps-at-top false 2>/dev/null || true
  gsettings set $DOCK running-indicator-style 'DOTS' 2>/dev/null || true
  gsettings set $DOCK click-action 'focus-or-appspread' 2>/dev/null || true
  gsettings set $DOCK scroll-action 'switch-workspace' 2>/dev/null || true
  gsettings set $DOCK transparency-mode 'DEFAULT' 2>/dev/null || true
  gsettings set $DOCK background-opacity 0.8 2>/dev/null || true
  gsettings set $DOCK multi-monitor false 2>/dev/null || true

  # ── Pin our apps to the dock (favorites) ──────────────────
  # Only pin apps whose .desktop actually exists; each line lists candidate
  # names (apt vs snap) and the first that exists on disk wins.
  DESKTOP_DIRS=(/usr/share/applications "$HOME/.local/share/applications" /var/lib/snapd/desktop/applications)
  _pick_desktop() {
    local d f
    for d in "${DESKTOP_DIRS[@]}"; do
      for f in "$@"; do [ -f "$d/$f" ] && { echo "$f"; return 0; }; done
    done
    return 1
  }
  FAVORITES=()
  while IFS= read -r cands; do
    [ -z "$cands" ] && continue
    picked=$(_pick_desktop $cands) && FAVORITES+=("$picked")
  done << 'APPS'
org.gnome.Nautilus.desktop
brave-browser.desktop brave_brave.desktop com.brave.Browser.desktop
terminator.desktop
code.desktop code_code.desktop
discord_discord.desktop discord.desktop
postman_postman.desktop postman.desktop
dbeaver-ce_dbeaver-ce.desktop dbeaver-ce.desktop dbeaver.desktop
spotify_spotify.desktop spotify.desktop
obsidian_obsidian.desktop obsidian.desktop
docker-desktop.desktop
OpenCode.desktop opencode.desktop
APPS
  if [ ${#FAVORITES[@]} -gt 0 ]; then
    fav_list=$(printf "'%s', " "${FAVORITES[@]}"); fav_list="[${fav_list%, }]"
    gsettings set org.gnome.shell favorite-apps "$fav_list" 2>/dev/null || true
    ok "Pinned ${#FAVORITES[@]} apps to the dock"
  fi

  # Window management shortcuts: Super+Q close, Super+F toggle maximize
  gsettings set org.gnome.desktop.wm.keybindings close "['<Super>q']" 2>/dev/null || true
  gsettings set org.gnome.desktop.wm.keybindings toggle-maximized "['<Super>f']" 2>/dev/null || true

  # GNOME Terminal: set FiraCode Nerd Font on the default profile
  if command -v dconf &>/dev/null; then
    PROFILE=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")
    if [ -n "$PROFILE" ]; then
      PROFILE_PATH="/org/gnome/terminal/legacy/profiles:/:$PROFILE/"
      dconf write "${PROFILE_PATH}use-system-font" "false" 2>/dev/null || true
      dconf write "${PROFILE_PATH}font" "'FiraCode Nerd Font 12'" 2>/dev/null || true
    fi
  fi
  ok "GNOME tweaks applied (dark mode, dock layout, pinned apps, wallpaper, terminal font)"
else
  warn "GNOME not detected — skipping GNOME tweaks"
fi

# ── Done ──────────────────────────────────────────────────────
echo -e "\n${GREEN}============================================${NC}"
echo -e "${GREEN}  Setup complete. Final steps:${NC}"
echo -e "  1. Close and reopen terminal (or: exec bash)"
echo -e "  2. ${CYAN}new-ssh${NC} — generate your SSH key and copy it to GitHub"
echo -e "  3. ${CYAN}sdk install java${NC} — if auto-install failed"
echo -e "  4. ${CYAN}update-all${NC} — to update everything in the future"
echo -e "  5. Open Brave and verify Bitwarden installed"
echo -e "  6. Restart so Docker works without sudo"
echo -e "  7. Log out/in if the dock layout or pinned apps didn't refresh"
echo -e "${GREEN}============================================${NC}\n"
