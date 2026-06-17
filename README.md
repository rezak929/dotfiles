# dotfiles

Shell configuration and new node setup for the [rk-k8s homelab](https://github.com/rezak929/k8s-homelab).

---

## Quick Start — New Node Setup

Run as root on a fresh Debian 13 (trixie) node:

```bash
git clone https://github.com/rezak929/dotfiles.git
cd dotfiles
bash setup.sh
```

The script is interactive and will prompt for:
- Hostname and IP of the new node
- Git name and email (defaults to Reza Khan / rezak929@gmail.com)
- Any additional node IPs beyond the known list

---

## What setup.sh does

| Step | Action |
|------|--------|
| 1 | Install prerequisites (zsh, git, curl, unzip, etc.) |
| 2 | Create reza user with passwordless sudo |
| 3 | Install oh-my-posh system-wide (`/usr/local/bin`) |
| 4 | Install gitleaks system-wide (`/usr/local/bin`) |
| 5 | Install oh-my-zsh + plugins for root |
| 6 | Install oh-my-zsh + plugins for reza |
| 7 | Configure git (name, email, pull.rebase) |
| 8 | Clone git-hooks repo + set core.hooksPath for both users |
| 9 | Generate SSH keys + distribute to all known nodes |
| 10 | Optionally distribute to additional nodes |

---

## Repo Structure

```
dotfiles/

├── setup.sh                      # New machine setup script (Linux nodes)
├── setup-mac.sh                  # New machine setup script (macOS)
├── zshrc.reza                    # zshrc for reza user
├── zshrc.root                    # zshrc for root user
├── dracula-linux.omp.json        # Oh My Posh theme — Debian/Linux nodes
├── dracula-mac.omp.json          # Oh My Posh theme — macOS
├── dracula-windows.omp.json      # Oh My Posh theme — Windows PowerShell
└── dracula-wsl.omp.json          # Oh My Posh theme — WSL
```

---

## Known Nodes

| Node | IP |
|------|----|
| rk-k8s-cp01 | 192.168.1.100 |
| rk-k8s-worker01 | 192.168.1.101 |
| rk-k8s-worker02 | 192.168.1.102 |
| rk-k8s-worker03 | 192.168.1.103 |
| rk-docker1 | 192.168.1.171 |

---

## Related Repos

- [k8s-homelab](https://github.com/rezak929/k8s-homelab) — K8s manifests and docs site
- [git-hooks](https://github.com/rezak929/git-hooks) — Gitleaks pre-push hook
