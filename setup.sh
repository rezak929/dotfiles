#!/bin/bash
# setup.sh — New machine setup for rk-k8s homelab
# Run as root on a fresh Debian 13 (trixie) node
# Usage: bash setup.sh
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
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[ERROR]${NC} Must be run as root. Use: sudo bash setup.sh"
  exit 1
fi

# ── Platform detection ────────────────────────────────────────────────────────
detect_platform() {
  if grep -qi microsoft /proc/version 2>/dev/null; then
    echo "wsl"
  elif [[ "$(uname)" == "Darwin" ]]; then
    echo "mac"
  else
    echo "linux"
  fi
}

PLATFORM=$(detect_platform)
info "Detected platform: ${BOLD}$PLATFORM${NC}"

case "$PLATFORM" in
  wsl)   OMP_THEME="dracula-wsl.omp.json" ;;
  mac)   OMP_THEME="dracula-mac.omp.json" ;;
  *)     OMP_THEME="dracula-linux.omp.json" ;;
esac

DOTFILES_RAW="https://raw.githubusercontent.com/rezak929/dotfiles/main"

header "rk-k8s Homelab — New Node Setup"
echo ""
prompt "Enter the hostname for this node (e.g. rk-k8s-worker03):"
read -r NODE_HOSTNAME

prompt "Enter this node's IP address (e.g. 192.168.1.103):"
read -r NODE_IP

prompt "Git name (default: Reza Khan):"
read -r GIT_NAME
GIT_NAME=${GIT_NAME:-"Reza Khan"}

prompt "Git email (default: rezak929@gmail.com):"
read -r GIT_EMAIL
GIT_EMAIL=${GIT_EMAIL:-"rezak929@gmail.com"}

echo ""
info "Setting up node: ${BOLD}$NODE_HOSTNAME${NC} ($NODE_IP)"
info "OMP theme: ${BOLD}$OMP_THEME${NC}"
echo ""

# ── Known nodes ──────────────────────────────────────────────────────────────
KNOWN_NODES=(
  "192.168.1.100"
  "192.168.1.101"
  "192.168.1.102"
  "192.168.1.103"
  "192.168.1.171"
)

# ── Step 1: Prerequisites ────────────────────────────────────────────────────
header "1. Installing prerequisites"

apt-get update -q
apt-get install -y -q \
  zsh git curl wget unzip jq sudo \
  openssh-client apt-transport-https \
  ca-certificates gnupg gpg

# Modern CLI tools
apt-get install -y -q fzf bat zoxide btop tealdeer 2>/dev/null || true

# Update tldr cache
tldr --update 2>/dev/null || true

# eza — try apt first, fall back to GitHub release
if ! apt-get install -y -q eza 2>/dev/null; then
  info "Installing eza from GitHub releases..."
  curl -sL https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz \
    | tar xz -C /usr/local/bin
fi

# bat is called batcat on Debian/Ubuntu — symlink it
[ -f /usr/bin/batcat ] && ln -sf /usr/bin/batcat /usr/local/bin/bat

success "Prerequisites installed"

# ── Step 2: Create reza user if needed ───────────────────────────────────────
header "2. Configuring reza user"

if ! id reza &>/dev/null; then
  info "Creating user reza..."
  useradd -m -s /usr/bin/zsh -G sudo reza
  prompt "Set password for reza:"
  passwd reza
else
  info "User reza already exists"
  chsh -s /usr/bin/zsh reza
fi

echo "reza ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/reza
chmod 440 /etc/sudoers.d/reza
success "reza configured with passwordless sudo"

# ── Step 3: Install oh-my-posh (system-wide) ─────────────────────────────────
header "3. Installing oh-my-posh"

curl -sL "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-amd64" \
  -o /usr/local/bin/oh-my-posh
chmod +x /usr/local/bin/oh-my-posh
success "oh-my-posh $(oh-my-posh --version) installed to /usr/local/bin"

# ── Step 4: Install gitleaks ─────────────────────────────────────────────────
header "4. Installing gitleaks"

GITLEAKS_VERSION=$(curl -s https://api.github.com/repos/gitleaks/gitleaks/releases/latest \
  | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
curl -sL "https://github.com/gitleaks/gitleaks/releases/latest/download/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
  -o /tmp/gitleaks.tar.gz
tar -xzf /tmp/gitleaks.tar.gz -C /tmp gitleaks
mv /tmp/gitleaks /usr/local/bin/gitleaks
chmod +x /usr/local/bin/gitleaks
rm /tmp/gitleaks.tar.gz
success "gitleaks $(gitleaks version) installed"

# ── Step 5: Download OMP themes ──────────────────────────────────────────────
header "5. Downloading OMP themes"

mkdir -p /root/.config/k8s/zsh-profile
mkdir -p /home/reza/.config/k8s/zsh-profile

for THEME in dracula-linux.omp.json dracula-windows.omp.json dracula-wsl.omp.json dracula-mac.omp.json; do
  curl -sL "$DOTFILES_RAW/$THEME" -o "/root/.config/k8s/zsh-profile/$THEME"
  cp "/root/.config/k8s/zsh-profile/$THEME" "/home/reza/.config/k8s/zsh-profile/$THEME"
done

chown -R reza:reza /home/reza/.config
success "OMP themes downloaded (platform: $OMP_THEME)"

# ── Step 6: oh-my-zsh + plugins for root ─────────────────────────────────────
header "6. Setting up zsh for root"

if [ ! -d /root/.oh-my-zsh ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

ZSH_CUSTOM_ROOT=/root/.oh-my-zsh/custom/plugins
[ ! -d "$ZSH_CUSTOM_ROOT/zsh-autosuggestions" ] && \
  git clone -q https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM_ROOT/zsh-autosuggestions"
[ ! -d "$ZSH_CUSTOM_ROOT/zsh-syntax-highlighting" ] && \
  git clone -q https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM_ROOT/zsh-syntax-highlighting"

curl -sL "$DOTFILES_RAW/zshrc.root" -o /root/.zshrc
sed -i "s|~/.config/oh-my-posh/dracula-linux.omp.json|~/.config/k8s/zsh-profile/$OMP_THEME|" /root/.zshrc
chsh -s /usr/bin/zsh root
success "zsh configured for root (theme: $OMP_THEME)"

# ── Step 7: oh-my-zsh + plugins for reza ─────────────────────────────────────
header "7. Setting up zsh for reza"

REZA_HOME=/home/reza

if [ ! -d "$REZA_HOME/.oh-my-zsh" ]; then
  su - reza -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
fi

ZSH_CUSTOM_REZA=$REZA_HOME/.oh-my-zsh/custom/plugins
[ ! -d "$ZSH_CUSTOM_REZA/zsh-autosuggestions" ] && \
  su - reza -c "git clone -q https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM_REZA/zsh-autosuggestions"
[ ! -d "$ZSH_CUSTOM_REZA/zsh-syntax-highlighting" ] && \
  su - reza -c "git clone -q https://github.com/zsh-users/zsh-syntax-highlighting $ZSH_CUSTOM_REZA/zsh-syntax-highlighting"

curl -sL "$DOTFILES_RAW/zshrc.reza" -o "$REZA_HOME/.zshrc"
sed -i "s|~/.config/oh-my-posh/dracula-linux.omp.json|~/.config/k8s/zsh-profile/$OMP_THEME|" "$REZA_HOME/.zshrc"
chown reza:reza "$REZA_HOME/.zshrc"
success "zsh configured for reza (theme: $OMP_THEME)"

# ── Step 8: git config ───────────────────────────────────────────────────────
header "8. Configuring git"

for TARGET_USER in root reza; do
  su - "$TARGET_USER" -c "
    git config --global user.name '$GIT_NAME'
    git config --global user.email '$GIT_EMAIL'
    git config --global pull.rebase true
    git config --global init.defaultBranch main
  "
done
success "git configured for root and reza"

# ── Step 9: git-hooks (gitleaks pre-push) ────────────────────────────────────
header "9. Installing git-hooks"

for TARGET_USER in root reza; do
  USER_HOME=$(eval echo ~$TARGET_USER)
  HOOKS_DIR="$USER_HOME/git-hooks"

  if [ ! -d "$HOOKS_DIR" ]; then
    su - "$TARGET_USER" -c "git clone -q https://github.com/rezak929/git-hooks.git $HOOKS_DIR"
  else
    su - "$TARGET_USER" -c "cd $HOOKS_DIR && git pull -q"
  fi

  chmod +x "$HOOKS_DIR/.githooks/pre-push"
  su - "$TARGET_USER" -c "git config --global core.hooksPath $HOOKS_DIR/.githooks"
done
success "git-hooks installed for root and reza"

# ── Step 10: SSH keys ─────────────────────────────────────────────────────────
header "10. Setting up SSH keys"

for TARGET_USER in root reza; do
  USER_HOME=$(eval echo ~$TARGET_USER)
  KEY="$USER_HOME/.ssh/id_ed25519"
  mkdir -p "$USER_HOME/.ssh"
  chmod 700 "$USER_HOME/.ssh"
  if [ ! -f "$KEY" ]; then
    su - "$TARGET_USER" -c "ssh-keygen -t ed25519 -f $KEY -N '' -C '${TARGET_USER}@${NODE_HOSTNAME}' -q"
  fi
done
chown -R reza:reza /home/reza/.ssh

ROOT_PUBKEY=$(cat /root/.ssh/id_ed25519.pub)
REZA_PUBKEY=$(cat /home/reza/.ssh/id_ed25519.pub)

echo ""
warn "You will be prompted for passwords on existing nodes."
echo ""

for NODE in "${KNOWN_NODES[@]}"; do
  [ "$NODE" = "$NODE_IP" ] && continue
  echo -e "  ${CYAN}→ $NODE${NC}"
  ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@"$NODE" \
    "echo '$ROOT_PUBKEY' >> ~/.ssh/authorized_keys && sort -u ~/.ssh/authorized_keys > /tmp/ak && mv /tmp/ak ~/.ssh/authorized_keys" 2>/dev/null && \
    echo "    root key → root@$NODE ✓" || warn "    Could not reach root@$NODE"
  ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 reza@"$NODE" \
    "echo '$REZA_PUBKEY' >> ~/.ssh/authorized_keys && sort -u ~/.ssh/authorized_keys > /tmp/ak && mv /tmp/ak ~/.ssh/authorized_keys" 2>/dev/null && \
    echo "    reza key → reza@$NODE ✓" || warn "    Could not reach reza@$NODE"
done

# Collect existing node keys into this node
COMBINED_ROOT="$ROOT_PUBKEY"
COMBINED_REZA="$REZA_PUBKEY"
for NODE in "${KNOWN_NODES[@]}"; do
  [ "$NODE" = "$NODE_IP" ] && continue
  EX_ROOT=$(ssh -o BatchMode=yes -o ConnectTimeout=5 root@"$NODE" "cat ~/.ssh/id_ed25519.pub" 2>/dev/null)
  EX_REZA=$(ssh -o BatchMode=yes -o ConnectTimeout=5 reza@"$NODE" "cat ~/.ssh/id_ed25519.pub" 2>/dev/null)
  [ -n "$EX_ROOT" ] && COMBINED_ROOT="$COMBINED_ROOT
$EX_ROOT"
  [ -n "$EX_REZA" ] && COMBINED_REZA="$COMBINED_REZA
$EX_REZA"
done

echo "$COMBINED_ROOT" | sort -u >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
echo "$COMBINED_REZA" | sort -u >> /home/reza/.ssh/authorized_keys
chmod 600 /home/reza/.ssh/authorized_keys
chown reza:reza /home/reza/.ssh/authorized_keys

success "SSH keys distributed"

# ── Step 11: Optional extra nodes ────────────────────────────────────────────
prompt "Add any additional node IPs? (comma-separated, or press Enter to skip):"
read -r EXTRA_NODES
if [ -n "$EXTRA_NODES" ]; then
  IFS=',' read -ra EXTRA_ARRAY <<< "$EXTRA_NODES"
  for NODE in "${EXTRA_ARRAY[@]}"; do
    NODE=$(echo "$NODE" | tr -d ' ')
    ssh -o StrictHostKeyChecking=no root@"$NODE" \
      "echo '$ROOT_PUBKEY' >> ~/.ssh/authorized_keys && sort -u ~/.ssh/authorized_keys > /tmp/ak && mv /tmp/ak ~/.ssh/authorized_keys" 2>/dev/null && \
      echo "  root key → root@$NODE ✓" || warn "  Could not reach root@$NODE"
    ssh -o StrictHostKeyChecking=no reza@"$NODE" \
      "echo '$REZA_PUBKEY' >> ~/.ssh/authorized_keys && sort -u ~/.ssh/authorized_keys > /tmp/ak && mv /tmp/ak ~/.ssh/authorized_keys" 2>/dev/null && \
      echo "  reza key → reza@$NODE ✓" || warn "  Could not reach reza@$NODE"
  done
fi

# ── Done ─────────────────────────────────────────────────────────────────────
header "Setup Complete!"
echo ""
echo -e "  ${GREEN}✓${NC} Hostname:      $NODE_HOSTNAME"
echo -e "  ${GREEN}✓${NC} Platform:      $PLATFORM"
echo -e "  ${GREEN}✓${NC} OMP theme:     $OMP_THEME"
echo -e "  ${GREEN}✓${NC} Users:         root, reza (passwordless sudo)"
echo -e "  ${GREEN}✓${NC} Shell:         zsh + oh-my-zsh + Dracula theme"
echo -e "  ${GREEN}✓${NC} oh-my-posh:    $(oh-my-posh --version)"
echo -e "  ${GREEN}✓${NC} gitleaks:      $(gitleaks version)"
echo -e "  ${GREEN}✓${NC} CLI tools:     eza, bat, fzf, zoxide, btop, tldr"
echo -e "  ${GREEN}✓${NC} git hooks:     ~/git-hooks/.githooks"
echo -e "  ${GREEN}✓${NC} SSH keys:      distributed to all known nodes"
echo ""
warn "Next steps:"
echo "  1. Source your shell: exec zsh"
echo "  2. If this is a K8s node, join the cluster:"
echo "     curl -sfL https://get.k3s.io | K3S_URL=https://192.168.1.100:6443 K3S_TOKEN=<token> sh -"
echo ""
