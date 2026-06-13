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
  zsh \
  git \
  curl \
  wget \
  unzip \
  jq \
  sudo \
  openssh-client \
  apt-transport-https \
  ca-certificates \
  gnupg

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
  # Ensure shell is zsh
  chsh -s /usr/bin/zsh reza
fi

# sudo without password
echo "reza ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/reza
chmod 440 /etc/sudoers.d/reza
success "reza configured with passwordless sudo"

# ── Step 3: Install oh-my-posh (system-wide) ─────────────────────────────────
header "3. Installing oh-my-posh"

OMP_VERSION=$(curl -s https://api.github.com/repos/JanDeDobbeleer/oh-my-posh/releases/latest | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
info "Installing oh-my-posh v${OMP_VERSION}..."
curl -sL "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-amd64" -o /usr/local/bin/oh-my-posh
chmod +x /usr/local/bin/oh-my-posh
success "oh-my-posh $(oh-my-posh --version) installed to /usr/local/bin"

# ── Step 4: Install gitleaks ─────────────────────────────────────────────────
header "4. Installing gitleaks"

GITLEAKS_VERSION=$(curl -s https://api.github.com/repos/gitleaks/gitleaks/releases/latest | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
info "Installing gitleaks v${GITLEAKS_VERSION}..."
curl -sL "https://github.com/gitleaks/gitleaks/releases/latest/download/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" -o /tmp/gitleaks.tar.gz
tar -xzf /tmp/gitleaks.tar.gz -C /tmp gitleaks
mv /tmp/gitleaks /usr/local/bin/gitleaks
chmod +x /usr/local/bin/gitleaks
rm /tmp/gitleaks.tar.gz
success "gitleaks $(gitleaks version) installed"

# ── Step 5: oh-my-zsh + plugins for root ─────────────────────────────────────
header "5. Setting up zsh for root"

if [ ! -d /root/.oh-my-zsh ]; then
  info "Installing oh-my-zsh for root..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  info "oh-my-zsh already installed for root"
fi

# Plugins
ZSH_CUSTOM_ROOT=/root/.oh-my-zsh/custom/plugins
if [ ! -d "$ZSH_CUSTOM_ROOT/zsh-autosuggestions" ]; then
  git clone -q https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM_ROOT/zsh-autosuggestions"
fi
if [ ! -d "$ZSH_CUSTOM_ROOT/zsh-syntax-highlighting" ]; then
  git clone -q https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM_ROOT/zsh-syntax-highlighting"
fi

# Theme
mkdir -p /root/.config/oh-my-posh
cp "$(dirname "$0")/omp/dracula-custom.omp.json" /root/.config/oh-my-posh/dracula-custom.omp.json

# zshrc
cp "$(dirname "$0")/zsh/.zshrc.root" /root/.zshrc

# Set default shell
chsh -s /usr/bin/zsh root
success "zsh configured for root"

# ── Step 6: oh-my-zsh + plugins for reza ─────────────────────────────────────
header "6. Setting up zsh for reza"

REZA_HOME=/home/reza

if [ ! -d "$REZA_HOME/.oh-my-zsh" ]; then
  info "Installing oh-my-zsh for reza..."
  su - reza -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
else
  info "oh-my-zsh already installed for reza"
fi

# Plugins
ZSH_CUSTOM_REZA=$REZA_HOME/.oh-my-zsh/custom/plugins
if [ ! -d "$ZSH_CUSTOM_REZA/zsh-autosuggestions" ]; then
  su - reza -c "git clone -q https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM_REZA/zsh-autosuggestions"
fi
if [ ! -d "$ZSH_CUSTOM_REZA/zsh-syntax-highlighting" ]; then
  su - reza -c "git clone -q https://github.com/zsh-users/zsh-syntax-highlighting $ZSH_CUSTOM_REZA/zsh-syntax-highlighting"
fi

# Theme
mkdir -p "$REZA_HOME/.config/oh-my-posh"
cp "$(dirname "$0")/omp/dracula-custom.omp.json" "$REZA_HOME/.config/oh-my-posh/dracula-custom.omp.json"
chown -R reza:reza "$REZA_HOME/.config"

# zshrc
cp "$(dirname "$0")/zsh/.zshrc.reza" "$REZA_HOME/.zshrc"
chown reza:reza "$REZA_HOME/.zshrc"

success "zsh configured for reza"

# ── Step 7: git config ───────────────────────────────────────────────────────
header "7. Configuring git"

for USER_HOME in /root "$REZA_HOME"; do
  TARGET_USER=$([ "$USER_HOME" = "/root" ] && echo "root" || echo "reza")
  su - "$TARGET_USER" -c "
    git config --global user.name '$GIT_NAME'
    git config --global user.email '$GIT_EMAIL'
    git config --global pull.rebase true
  "
done
success "git configured for root and reza"

# ── Step 8: git-hooks (gitleaks pre-push) ────────────────────────────────────
header "8. Installing git-hooks"

for USER_HOME in /root "$REZA_HOME"; do
  TARGET_USER=$([ "$USER_HOME" = "/root" ] && echo "root" || echo "reza")
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

# ── Step 9: SSH keys ─────────────────────────────────────────────────────────
header "9. Setting up SSH keys"

# Generate keys if missing
for USER_HOME in /root "$REZA_HOME"; do
  TARGET_USER=$([ "$USER_HOME" = "/root" ] && echo "root" || echo "reza")
  KEY="$USER_HOME/.ssh/id_ed25519"
  if [ ! -f "$KEY" ]; then
    info "Generating SSH key for $TARGET_USER..."
    su - "$TARGET_USER" -c "ssh-keygen -t ed25519 -f $KEY -N '' -C '${TARGET_USER}@${NODE_HOSTNAME}' -q"
  else
    info "SSH key already exists for $TARGET_USER"
  fi
done

# Collect and distribute keys to all known nodes
echo ""
info "Distributing SSH keys to known nodes..."
echo ""
warn "You will be prompted for passwords on each existing node."
echo ""

ROOT_PUBKEY=$(cat /root/.ssh/id_ed25519.pub)
REZA_PUBKEY=$(cat "$REZA_HOME/.ssh/id_ed25519.pub")

for NODE in "${KNOWN_NODES[@]}"; do
  if [ "$NODE" = "$NODE_IP" ]; then
    continue
  fi
  echo -e "  ${CYAN}→ $NODE${NC}"
  # Add root key to root@node
  ssh -o StrictHostKeyChecking=no root@"$NODE" \
    "echo '$ROOT_PUBKEY' >> ~/.ssh/authorized_keys && sort -u ~/.ssh/authorized_keys > /tmp/ak && mv /tmp/ak ~/.ssh/authorized_keys" 2>/dev/null && \
    echo "    root key → root@$NODE ✓" || warn "    Could not reach root@$NODE"

  # Add reza key to reza@node
  ssh -o StrictHostKeyChecking=no reza@"$NODE" \
    "echo '$REZA_PUBKEY' >> ~/.ssh/authorized_keys && sort -u ~/.ssh/authorized_keys > /tmp/ak && mv /tmp/ak ~/.ssh/authorized_keys" 2>/dev/null && \
    echo "    reza key → reza@$NODE ✓" || warn "    Could not reach reza@$NODE"
done

# Also get existing nodes' keys and add them to this node
info "Collecting keys from existing nodes and adding to this node..."

COMBINED_ROOT_KEYS="$ROOT_PUBKEY"
COMBINED_REZA_KEYS="$REZA_PUBKEY"

for NODE in "${KNOWN_NODES[@]}"; do
  if [ "$NODE" = "$NODE_IP" ]; then
    continue
  fi
  EXISTING_ROOT=$(ssh -o BatchMode=yes -o ConnectTimeout=5 root@"$NODE" "cat ~/.ssh/id_ed25519.pub" 2>/dev/null)
  EXISTING_REZA=$(ssh -o BatchMode=yes -o ConnectTimeout=5 reza@"$NODE" "cat ~/.ssh/id_ed25519.pub" 2>/dev/null)
  [ -n "$EXISTING_ROOT" ] && COMBINED_ROOT_KEYS="$COMBINED_ROOT_KEYS
$EXISTING_ROOT"
  [ -n "$EXISTING_REZA" ] && COMBINED_REZA_KEYS="$COMBINED_REZA_KEYS
$EXISTING_REZA"
done

# Write combined keys to authorized_keys on this node
mkdir -p /root/.ssh
echo "$COMBINED_ROOT_KEYS" | sort -u >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

mkdir -p "$REZA_HOME/.ssh"
echo "$COMBINED_REZA_KEYS" | sort -u >> "$REZA_HOME/.ssh/authorized_keys"
chmod 600 "$REZA_HOME/.ssh/authorized_keys"
chown -R reza:reza "$REZA_HOME/.ssh"

success "SSH keys distributed"

# ── Step 10: Add optional new node IP ────────────────────────────────────────
prompt "Add any additional node IPs to distribute keys to? (comma-separated, or press Enter to skip):"
read -r EXTRA_NODES
if [ -n "$EXTRA_NODES" ]; then
  IFS=',' read -ra EXTRA_ARRAY <<< "$EXTRA_NODES"
  for NODE in "${EXTRA_ARRAY[@]}"; do
    NODE=$(echo "$NODE" | tr -d ' ')
    info "Distributing to $NODE..."
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
echo -e "  ${GREEN}✓${NC} Users:         root, reza (passwordless sudo)"
echo -e "  ${GREEN}✓${NC} Shell:         zsh + oh-my-zsh + Dracula theme"
echo -e "  ${GREEN}✓${NC} oh-my-posh:    $(oh-my-posh --version)"
echo -e "  ${GREEN}✓${NC} gitleaks:      $(gitleaks version)"
echo -e "  ${GREEN}✓${NC} git hooks:     ~/git-hooks/.githooks"
echo -e "  ${GREEN}✓${NC} SSH keys:      distributed to all known nodes"
echo ""
warn "Next steps:"
echo "  1. Source your shell: exec zsh"
echo "  2. If this is a K8s node, join the cluster:"
echo "     curl -sfL https://get.k3s.io | K3S_URL=https://192.168.1.100:6443 K3S_TOKEN=<token> sh -"
echo ""
