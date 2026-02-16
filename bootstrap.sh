#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Post-install bootstrap for: https://github.com/itsivali/Nixos-Dots
# Run AFTER: NixOS installed, GNOME selected, user created, logged in.
# ============================================================

REPO_URL="${REPO_URL:-https://github.com/itsivali/Nixos-Dots}"
BRANCH="${BRANCH:-main}"                 # change if your default isn't main
FLAKE_HOST="${FLAKE_HOST:-prague}"       # nixosConfigurations.prague
TARGET_DIR="${TARGET_DIR:-/etc/nixos}"
BACKUP="${BACKUP:-1}"                    # 1 = backup old /etc/nixos
ALLOW_UNFREE="${ALLOW_UNFREE:-1}"        # your HM apps include unfree
EXPECTED_USER="${EXPECTED_USER:-ivali}"  # your config defines users.users.ivali

if [[ "$(id -u)" -eq 0 ]]; then
  echo "ERROR: run as your normal user (not root)."
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "ERROR: sudo not found. Ensure your user is in wheel and sudo is enabled."
  exit 1
fi

echo "==> Enabling flakes (nix-command + flakes)..."
sudo mkdir -p /etc/nix
if [[ ! -f /etc/nix/nix.conf ]]; then
  echo "experimental-features = nix-command flakes" | sudo tee /etc/nix/nix.conf >/dev/null
else
  if ! grep -q "^experimental-features" /etc/nix/nix.conf; then
    echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf >/dev/null
  else
    # Ensure both are present (normalize line)
    if ! grep -q "flakes" /etc/nix/nix.conf || ! grep -q "nix-command" /etc/nix/nix.conf; then
      sudo sed -i 's/^experimental-features *=.*/experimental-features = nix-command flakes/' /etc/nix/nix.conf
    fi
  fi
fi
export NIX_CONFIG="${NIX_CONFIG:-} experimental-features = nix-command flakes"

echo "==> Ensuring git exists..."
if ! command -v git >/dev/null 2>&1; then
  # Prefer modern CLI if available, fallback to nix-env
  if command -v nix >/dev/null 2>&1 && nix --version >/dev/null 2>&1; then
    nix profile install nixpkgs#git
  else
    nix-env -iA nixpkgs.git
  fi
fi

echo "==> Capturing THIS machine's hardware-configuration.nix..."
HW_SRC="/etc/nixos/hardware-configuration.nix"
HW_TMP="$(mktemp -t hardware-configuration.nix.XXXXXX)"

if [[ -f "$HW_SRC" ]]; then
  sudo cp -f "$HW_SRC" "$HW_TMP"
else
  echo "   Not found; generating it..."
  sudo nixos-generate-config
  if [[ ! -f "$HW_SRC" ]]; then
    echo "ERROR: failed to generate $HW_SRC"
    exit 1
  fi
  sudo cp -f "$HW_SRC" "$HW_TMP"
fi

if [[ "$BACKUP" -eq 1 && -d "$TARGET_DIR" ]]; then
  TS="$(date +%Y%m%d-%H%M%S)"
  echo "==> Backing up $TARGET_DIR -> ${TARGET_DIR}.bak.${TS}"
  sudo mv "$TARGET_DIR" "${TARGET_DIR}.bak.${TS}"
fi

echo "==> Cloning repo to a temporary directory..."
CLONE_DIR="$(mktemp -d -t nixos-dots.XXXXXX)"
cleanup() {
  rm -rf "$CLONE_DIR" || true
  rm -f "$HW_TMP" || true
}
trap cleanup EXIT

if [[ -n "$BRANCH" ]]; then
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$CLONE_DIR"
else
  git clone --depth 1 "$REPO_URL" "$CLONE_DIR"
fi

echo "==> Overwriting repo hardware-configuration.nix with THIS machine's..."
cp -f "$HW_TMP" "$CLONE_DIR/hardware-configuration.nix"

echo "==> Installing repo into $TARGET_DIR..."
sudo mkdir -p "$TARGET_DIR"

# Safely clear target dir contents (including dotfiles) without glob errors.
# Use find so empty dirs don't cause failures under 'set -e'.
sudo find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +

# Copy clone into /etc/nixos
sudo cp -a "$CLONE_DIR"/. "$TARGET_DIR"/

if [[ "$ALLOW_UNFREE" -eq 1 ]]; then
  export NIXPKGS_ALLOW_UNFREE=1
fi

CURRENT_USER="$(id -un)"
if [[ "$CURRENT_USER" != "$EXPECTED_USER" ]]; then
  echo ""
  echo "NOTE:"
  echo "  You are logged in as '$CURRENT_USER', but your NixOS config defines user '$EXPECTED_USER'."
  echo "  That's okay: the rebuild will create '$EXPECTED_USER'."
  echo "  After rebuild, you can log into '$EXPECTED_USER' to get the Home Manager setup."
  echo ""
fi

echo "==> Switching system to flake host: $FLAKE_HOST"
sudo nixos-rebuild switch --flake "$TARGET_DIR#$FLAKE_HOST"

echo ""
echo "✅ Bootstrap complete."
echo "If GNOME theme/extensions don’t apply immediately, log out/in or reboot."

