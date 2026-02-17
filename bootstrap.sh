#!/usr/bin/env bash
set -euo pipefail



# --------- Config (override via env vars) ----------
REPO_HTTPS="${REPO_HTTPS:-https://github.com/itsivali/Nixos-Dots}"
REPO_SSH="${REPO_SSH:-git@github.com:itsivali/Nixos-Dots.git}"
BRANCH="${BRANCH:-main}"

DEST_DIR="${DEST_DIR:-$HOME/Nixos-Dots}"

# Recommended option: keep /etc/nixos as a symlink to your HOME repo
LINK_ETC_NIXOS="${LINK_ETC_NIXOS:-1}"

# Detect host automatically (works if flake uses hostname as config name)
AUTO_HOST="$(hostname -s 2>/dev/null || true)"
FLAKE_HOST="${FLAKE_HOST:-${AUTO_HOST:-prague}}"

GIT_NAME="${GIT_NAME:-Willis Ivali}"
GIT_EMAIL="${GIT_EMAIL:-itsivali@outlook.com}"

# --------- Helpers ----------
die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "==> $*"; }


if [[ "$(pwd -P 2>/dev/null || true)" == "/etc/nixos"* ]]; then
  cd "$HOME"
fi

# Must not run as root
[[ "$(id -u)" -ne 0 ]] || die "Run as your normal user (not root)."

command -v sudo >/dev/null 2>&1 || die "sudo not found."
command -v nix  >/dev/null 2>&1 || die "nix not found (are you on NixOS?)."


sudo -v

info "Enabling flakes (nix-command + flakes)..."
sudo mkdir -p /etc/nix
if [[ ! -f /etc/nix/nix.conf ]]; then
  echo "experimental-features = nix-command flakes" | sudo tee /etc/nix/nix.conf >/dev/null
else
  if ! grep -q '^experimental-features' /etc/nix/nix.conf; then
    echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf >/dev/null
  elif ! grep -q 'nix-command' /etc/nix/nix.conf || ! grep -q 'flakes' /etc/nix/nix.conf; then
    sudo sed -i 's/^experimental-features *=.*/experimental-features = nix-command flakes/' /etc/nix/nix.conf
  fi
fi
export NIX_CONFIG="${NIX_CONFIG:-} experimental-features = nix-command flakes"

info "Ensuring basic tools exist (git, ssh)..."
need_pkgs=()
command -v git >/dev/null 2>&1 || need_pkgs+=("nixpkgs#git")
command -v ssh >/dev/null 2>&1 || need_pkgs+=("nixpkgs#openssh")
command -v ssh-keygen >/dev/null 2>&1 || need_pkgs+=("nixpkgs#openssh")
if (( ${#need_pkgs[@]} > 0 )); then
  nix profile install "${need_pkgs[@]}"
fi

info "Capturing THIS machine's hardware-configuration.nix..."
HW_SRC="/etc/nixos/hardware-configuration.nix"
HW_TMP="$(mktemp -t hardware-configuration.nix.XXXXXX)"
cleanup() { rm -f "$HW_TMP" || true; }
trap cleanup EXIT

if [[ -f "$HW_SRC" ]]; then
  sudo cp -f "$HW_SRC" "$HW_TMP"
else
  info "hardware-configuration.nix not found in /etc/nixos; generating..."
  sudo nixos-generate-config
  [[ -f "$HW_SRC" ]] || die "Failed to generate $HW_SRC"
  sudo cp -f "$HW_SRC" "$HW_TMP"
fi

info "Cloning/updating repo into: $DEST_DIR"
if [[ -d "$DEST_DIR/.git" ]]; then
  # Safety: do not overwrite local work
  if ! git -C "$DEST_DIR" diff --quiet || ! git -C "$DEST_DIR" diff --cached --quiet; then
    info "Repo has local changes; skipping pull for safety."
    info "You can review with: cd '$DEST_DIR' && git status"
  else
    git -C "$DEST_DIR" fetch --all --prune
    git -C "$DEST_DIR" checkout "$BRANCH" >/dev/null 2>&1 || true
    git -C "$DEST_DIR" pull --ff-only || true
  fi
else
  mkdir -p "$(dirname "$DEST_DIR")"
  git clone --branch "$BRANCH" "$REPO_HTTPS" "$DEST_DIR"
fi

info "Writing hardware-configuration.nix into repo..."
cp -f "$HW_TMP" "$DEST_DIR/hardware-configuration.nix"

# Git safety (especially if /etc/nixos links here)
git config --global --add safe.directory "$DEST_DIR" >/dev/null 2>&1 || true
git -C "$DEST_DIR" config user.name  "$GIT_NAME"  >/dev/null 2>&1 || true
git -C "$DEST_DIR" config user.email "$GIT_EMAIL" >/dev/null 2>&1 || true

if [[ "$LINK_ETC_NIXOS" == "1" ]]; then
  info "Linking /etc/nixos -> $DEST_DIR (safe swap)..."
  # Never rm -rf a live directory. If /etc/nixos is a real dir, back it up once.
  if [[ -e /etc/nixos && ! -L /etc/nixos ]]; then
    TS="$(date +%Y%m%d-%H%M%S)"
    BACKUP="/etc/nixos.backup-$TS"
    info "/etc/nixos is a directory; backing up to $BACKUP"
    sudo mv /etc/nixos "$BACKUP"
  fi

  # Atomic symlink update (safe even if /etc/nixos exists as symlink)
  sudo mkdir -p /etc
  sudo ln -sfn "$DEST_DIR" /etc/nixos
  sudo chown -h root:root /etc/nixos
fi

info "Setting up GitHub push via SSH..."
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

KEY="$HOME/.ssh/id_ed25519"
PUB="$KEY.pub"

if [[ ! -f "$KEY" ]]; then
  ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$KEY" -N ""
fi

# Start agent if needed (best-effort)
if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
  eval "$(ssh-agent -s)" >/dev/null || true
fi
ssh-add "$KEY" >/dev/null 2>&1 || true

# Ensure origin uses SSH (so push works without tokens)
if git -C "$DEST_DIR" remote get-url origin >/dev/null 2>&1; then
  git -C "$DEST_DIR" remote set-url origin "$REPO_SSH" || true
else
  git -C "$DEST_DIR" remote add origin "$REPO_SSH" || true
fi

echo ""
info "Your GitHub SSH public key (add to GitHub -> Settings -> SSH keys):"
echo "--------------------------------------------------------------------------"
cat "$PUB"
echo "--------------------------------------------------------------------------"
echo ""

info "Creating handy commands in ~/.local/bin (work from anywhere)..."
mkdir -p "$HOME/.local/bin"

cat > "$HOME/.local/bin/nxswitch" <<EOF
#!/usr/bin/env bash
set -euo pipefail
sudo nixos-rebuild switch --flake "$DEST_DIR#$FLAKE_HOST"
EOF

cat > "$HOME/.local/bin/nxupdate" <<EOF
#!/usr/bin/env bash
set -euo pipefail
nix flake update "$DEST_DIR"
sudo nixos-rebuild switch --flake "$DEST_DIR#$FLAKE_HOST"
EOF

cat > "$HOME/.local/bin/nxedit" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec \${EDITOR:-nano} "$DEST_DIR"
EOF

chmod +x "$HOME/.local/bin/"{nxswitch,nxupdate,nxedit}

# Make sure ~/.local/bin is on PATH for future sessions
if ! grep -qs 'export PATH="\$HOME/.local/bin:\$PATH"' "$HOME/.profile" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
fi
export PATH="$HOME/.local/bin:$PATH"

info "Rebuilding using flake from HOME: $DEST_DIR#$FLAKE_HOST"
cd "$HOME"
sudo nixos-rebuild switch --flake "$DEST_DIR#$FLAKE_HOST"

echo ""
echo "✅ Done."
echo "Next:"
echo "  - Rebuild anytime: nxswitch"
echo "  - Update inputs + rebuild: nxupdate"
echo "  - Edit config: nxedit"
echo "  - Push changes: cd '$DEST_DIR' && git status && git push"

