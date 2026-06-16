#!/bin/bash
# setup-mac.sh — New Mac setup for rk-k8s homelab + Fivetran
# Run as your normal user (no root/sudo needed for most steps)
# Usage: bash setup-mac.sh
set -e

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; AMBER='\033[0;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${AMBER}[WARN]${NC} $1"; }
prompt()  { echo -e "${BLUE}[INPUT]${NC} $1"; }
header()  { echo -e "\n${BOLD}${BLUE}══════════════════════════════════════${NC}"; echo -e "${BOLD}${BLUE} $1${NC}"; echo -e "${BOLD}${BLUE}══════════════════════════════════════${NC}"; }

# ── Sanity check ─────────────────────────────────────────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
  echo -e "${RED}[ERROR]${NC} This script is for macOS only. Use setup.sh for Linux nodes."
  exit 1
fi

if [ "$EUID" -eq 0 ]; then
  echo -e "${RED}[ERROR]${NC} Do NOT run as root. Run as your normal user: bash setup-mac.sh"
  exit 1
fi

DOTFILES_RAW="https://raw.githubusercontent.com/rezak929/dotfiles/main"
OMP_THEME="dracula-mac.omp.json"
CURRENT_USER=$(whoami)

header "rk-k8s Homelab — Mac Setup"
echo ""
info "Detected macOS: $(sw_vers -productVersion)"
info "Current user: ${BOLD}$CURRENT_USER${NC}"
echo ""

prompt "Confirm your username (press Enter to use '$CURRENT_USER', or type a different one):"
read -r INPUT_USER
MAC_USER=${INPUT_USER:-$CURRENT_USER}

prompt "Git name (default: Reza Khan):"
read -r GIT_NAME
GIT_NAME=${GIT_NAME:-"Reza Khan"}

prompt "Git email (default: rezak929@gmail.com):"
read -r GIT_EMAIL
GIT_EMAIL=${GIT_EMAIL:-"rezak929@gmail.com"}

echo ""
info "Setting up Mac for user: ${BOLD}$MAC_USER${NC}"
info "OMP theme: ${BOLD}$OMP_THEME${NC}"
echo ""

# ── Step 1: Xcode Command Line Tools ─────────────────────────────────────────
header "1. Xcode Command Line Tools"

if xcode-select -p &>/dev/null; then
  info "Xcode CLT already installed: $(xcode-select -p)"
else
  info "Installing Xcode Command Line Tools..."
  xcode-select --install
  warn "Xcode CLT install dialog opened — complete it then re-run this script."
  exit 0
fi
success "Xcode Command Line Tools ready"

# ── Step 2: Homebrew ──────────────────────────────────────────────────────────
header "2. Homebrew"

if command -v brew &>/dev/null; then
  info "Homebrew already installed: $(brew --version | head -1)"
  brew update
else
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to PATH for Apple Silicon
  if [[ "$(uname -m)" == "arm64" ]]; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi
success "Homebrew $(brew --version | head -1) ready"

# ── Step 3: Core CLI tools ────────────────────────────────────────────────────
header "3. Installing CLI tools"

BREW_PACKAGES=(
  zsh
  git
  curl
  wget
  jq
  fzf
  bat
  eza
  zoxide
  btop
  tealdeer
  oh-my-posh
  kubectl
  helm
  k9s
)

for pkg in "${BREW_PACKAGES[@]}"; do
  if brew list "$pkg" &>/dev/null; then
    info "$pkg already installed"
  else
    info "Installing $pkg..."
    brew install "$pkg"
  fi
done

success "CLI tools installed"

# ── Step 4: Nerd Font ─────────────────────────────────────────────────────────
header "4. Installing MesloLGS Nerd Font"

if brew list --cask font-meslo-lg-nerd-font &>/dev/null; then
  info "MesloLGS Nerd Font already installed"
else
  info "Installing MesloLGS Nerd Font..."
  brew tap homebrew/cask-fonts 2>/dev/null || true
  brew install --cask font-meslo-lg-nerd-font
fi
success "MesloLGS Nerd Font installed"
warn "Set MesloLGS NF as your terminal font manually in Terminal/iTerm2/Kitty preferences"

# ── Step 5: oh-my-zsh ────────────────────────────────────────────────────────
header "5. Setting up oh-my-zsh"

if [ -d ~/.oh-my-zsh ]; then
  info "oh-my-zsh already installed"
else
  info "Installing oh-my-zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

ZSH_CUSTOM=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
  info "Installing zsh-autosuggestions..."
  git clone -q https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
  info "Installing zsh-syntax-highlighting..."
  git clone -q https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

success "oh-my-zsh + plugins installed"

# ── Step 6: OMP themes ───────────────────────────────────────────────────────
header "6. Downloading OMP themes"

mkdir -p ~/.config/k8s/zsh-profile

for THEME in dracula-linux.omp.json dracula-mac.omp.json dracula-windows.omp.json dracula-wsl.omp.json; do
  info "Downloading $THEME..."
  curl -sL "$DOTFILES_RAW/$THEME" -o ~/.config/k8s/zsh-profile/$THEME
done

success "OMP themes downloaded to ~/.config/k8s/zsh-profile/"

# ── Step 7: .zshrc ───────────────────────────────────────────────────────────
header "7. Installing .zshrc"

ZSHRC_URL="$DOTFILES_RAW/zshrc.reza"

# Backup existing .zshrc if present
if [ -f ~/.zshrc ]; then
  cp ~/.zshrc ~/.zshrc.bak
  warn "Existing .zshrc backed up to ~/.zshrc.bak"
fi

curl -sL "$ZSHRC_URL" -o ~/.zshrc

# Update OMP theme path to mac theme
sed -i '' "s|~/.config/k8s/zsh-profile/dracula-linux.omp.json|~/.config/k8s/zsh-profile/$OMP_THEME|" ~/.zshrc

# Mac-specific: add Homebrew to PATH if Apple Silicon
if [[ "$(uname -m)" == "arm64" ]]; then
  if ! grep -q "brew shellenv" ~/.zshrc; then
    echo '' >> ~/.zshrc
    echo '# Homebrew (Apple Silicon)' >> ~/.zshrc
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
  fi
fi

# Mac-specific: fzf shell integration via Homebrew
if ! grep -q "fzf --zsh" ~/.zshrc; then
  cat >> ~/.zshrc << 'FZF'

# fzf (Homebrew — replaces manual key-bindings source on Linux)
if command -v fzf &>/dev/null; then
  eval "$(fzf --zsh)"
fi
FZF
fi

success ".zshrc installed (theme: $OMP_THEME)"

# ── Step 8: git config ───────────────────────────────────────────────────────
header "8. Configuring git"

git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
git config --global pull.rebase true
git config --global init.defaultBranch main
git config --global core.editor "code --wait"

success "git configured for $MAC_USER"

# ── Step 9: gitleaks ─────────────────────────────────────────────────────────
header "9. Installing gitleaks"

if brew list gitleaks &>/dev/null; then
  info "gitleaks already installed: $(gitleaks version)"
else
  brew install gitleaks
fi
success "gitleaks $(gitleaks version) installed"

# ── Step 10: git-hooks (gitleaks pre-push) ───────────────────────────────────
header "10. Installing git-hooks"

HOOKS_DIR="$HOME/git-hooks"

if [ ! -d "$HOOKS_DIR" ]; then
  git clone -q https://github.com/rezak929/git-hooks.git "$HOOKS_DIR"
else
  cd "$HOOKS_DIR" && git pull -q && cd -
fi

chmod +x "$HOOKS_DIR/.githooks/pre-push"
git config --global core.hooksPath "$HOOKS_DIR/.githooks"
success "git-hooks installed → $HOOKS_DIR/.githooks"

# ── Step 11: SSH key ─────────────────────────────────────────────────────────
header "11. Setting up SSH key"

KEY="$HOME/.ssh/id_ed25519"
mkdir -p ~/.ssh
chmod 700 ~/.ssh

if [ ! -f "$KEY" ]; then
  ssh-keygen -t ed25519 -f "$KEY" -N '' -C "${MAC_USER}@$(hostname -s)" -q
  success "SSH key generated: $KEY"
else
  info "SSH key already exists: $KEY"
fi

echo ""
info "Your public key (add to GitHub + homelab nodes):"
echo ""
cat "${KEY}.pub"
echo ""
warn "Run: ssh-copy-id reza@192.168.1.100 (and other homelab nodes)"

# ── Step 12: tldr cache ──────────────────────────────────────────────────────
header "12. Seeding tldr cache"
tldr --update 2>/dev/null && success "tldr cache updated" || warn "tldr cache update failed — run 'tldr --update' manually"

# ── Step 13: VS Code extensions ──────────────────────────────────────────────
header "13. VS Code extensions"

if command -v code &>/dev/null; then
  EXTENSIONS=(
    "ms-kubernetes-tools.vscode-kubernetes-tools"
    "ms-vscode-remote.remote-ssh"
    "ms-vscode-remote.remote-ssh-edit"
    "github.copilot"
    "eamodio.gitlens"
    "mhutchie.git-graph"
    "oderwat.indent-rainbow"
    "PKief.material-icon-theme"
  )
  for ext in "${EXTENSIONS[@]}"; do
    code --install-extension "$ext" --force 2>/dev/null && info "Installed: $ext" || warn "Failed: $ext"
  done
  success "VS Code extensions installed"
else
  warn "VS Code CLI (code) not found — install VS Code and add 'code' to PATH"
  warn "Then run: code --install-extension ms-kubernetes-tools.vscode-kubernetes-tools"
fi

# ── Done ─────────────────────────────────────────────────────────────────────
header "Mac Setup Complete!"
echo ""
echo -e "  ${GREEN}✓${NC} User:          $MAC_USER"
echo -e "  ${GREEN}✓${NC} macOS:         $(sw_vers -productVersion)"
echo -e "  ${GREEN}✓${NC} Homebrew:      $(brew --version | head -1)"
echo -e "  ${GREEN}✓${NC} oh-my-posh:    $(oh-my-posh --version)"
echo -e "  ${GREEN}✓${NC} gitleaks:      $(gitleaks version)"
echo -e "  ${GREEN}✓${NC} OMP theme:     $OMP_THEME"
echo -e "  ${GREEN}✓${NC} CLI tools:     eza, bat, fzf, zoxide, btop, tldr, kubectl, helm, k9s"
echo -e "  ${GREEN}✓${NC} git hooks:     ~/git-hooks/.githooks"
echo -e "  ${GREEN}✓${NC} SSH key:       ~/.ssh/id_ed25519"
echo ""
warn "Next steps:"
echo "  1. Reload shell:          exec zsh"
echo "  2. Set terminal font:     MesloLGS NF in terminal preferences"
echo "  3. Add SSH key to nodes:  ssh-copy-id reza@192.168.1.100 (repeat for each node)"
echo "  4. Copy kubeconfig:       scp reza@192.168.1.100:/etc/rancher/k3s/k3s.yaml ~/.kube/config"
echo "  5. Update kubeconfig IP:  sed -i '' 's/127.0.0.1/192.168.1.100/' ~/.kube/config"
echo "  6. Test cluster:          kubectl get nodes"
echo ""
