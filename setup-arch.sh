#!/bin/bash
# setup-arch.sh — shell setup for Arch/CachyOS (desktop, not a homelab node)
# Run as your normal user (NOT root): bash setup-arch.sh
set -e

DOTFILES_RAW="https://raw.githubusercontent.com/rezak929/dotfiles/main"

if [ "$EUID" -eq 0 ]; then
  echo "Run as your normal user, not root (sudo is used where needed)."; exit 1
fi

echo "==> 1. Packages (zsh + modern CLI tools + Nerd Font for icons)"
sudo pacman -S --needed --noconfirm \
  zsh git curl unzip jq \
  eza bat fzf zoxide btop tealdeer kubectl gitleaks \
  ttf-meslo-nerd
tldr --update 2>/dev/null || true

echo "==> 2. oh-my-posh (official installer -> ~/.local/bin)"
mkdir -p ~/.local/bin
command -v oh-my-posh >/dev/null || curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin

echo "==> 3. Dracula theme"
mkdir -p ~/.config/k8s/zsh-profile
curl -sL "$DOTFILES_RAW/dracula-linux.omp.json" -o ~/.config/k8s/zsh-profile/dracula-linux.omp.json

echo "==> 4. oh-my-zsh + plugins"
[ -d ~/.oh-my-zsh ] || RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
P=~/.oh-my-zsh/custom/plugins
[ -d "$P/zsh-autosuggestions" ]     || git clone -q https://github.com/zsh-users/zsh-autosuggestions "$P/zsh-autosuggestions"
[ -d "$P/zsh-syntax-highlighting" ] || git clone -q https://github.com/zsh-users/zsh-syntax-highlighting "$P/zsh-syntax-highlighting"

echo "==> 5. .zshrc (Arch fzf paths patched in)"
[ -f ~/.zshrc ] && cp ~/.zshrc ~/.zshrc.bak.$(date +%s)
curl -sL "$DOTFILES_RAW/zshrc.reza" -o ~/.zshrc
# Debian keeps fzf keybindings in /usr/share/doc/fzf/examples; Arch uses /usr/share/fzf
sed -i 's|/usr/share/doc/fzf/examples/|/usr/share/fzf/|g' ~/.zshrc

echo "==> 6. git"
git config --global user.name  "Reza Khan"
git config --global user.email "rezak929@gmail.com"
git config --global pull.rebase true
git config --global init.defaultBranch main

echo "==> 7. Default shell -> zsh"
chsh -s /usr/bin/zsh

echo
echo "Done. Next:"
echo "  1. Konsole -> Settings -> Edit Current Profile -> Appearance -> Font: 'MesloLGS Nerd Font'"
echo "  2. Log out and back in (or run: exec zsh)"
