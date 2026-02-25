#!/usr/bin/env bash
set -euo pipefail

FLAKE_HOST="prague"
REPO_DEFAULT="$HOME/Nixos-Dots"
MODE="${MODE:-link}" # link (default) or copy

# Only enable flakes here. Any download/network tuning must be in NixOS:
#   nix.settings = { ... }
NIX_FEATURES=$'experimental-features = nix-command flakes\n'

die()  { echo "ERROR: $*" >&2; exit 1; }
info() { echo "==> $*" >&2; }

[[ "$(id -u)" -ne 0 ]] || die "Run as your normal user (not root)."
command -v sudo >/dev/null 2>&1 || die "sudo not found."
command -v nix  >/dev/null 2>&1 || die "nix not found."

sudo -v

# Ensure user nix.conf enables flakes and DOES NOT include restricted daemon settings
NIX_CONF_DIR="$HOME/.config/nix"
NIX_CONF_FILE="$NIX_CONF_DIR/nix.conf"
mkdir -p "$NIX_CONF_DIR"
touch "$NIX_CONF_FILE"

# Remove restricted settings if present (these cause: 'ignored ... because it is a restricted setting')
# Keep this list conservative; you can add more if needed.
for k in download-attempts http-connections http2 narinfo-cache-negative-ttl connect-timeout; do
  # delete lines like: key = value
  sed -i -E "/^[[:space:]]*${k}[[:space:]]*=.*$/d" "$NIX_CONF_FILE"
done

# Ensure experimental-features is set (replace if exists, otherwise append)
if grep -qE '^[[:space:]]*experimental-features[[:space:]]*=' "$NIX_CONF_FILE"; then
  sed -i -E 's/^[[:space:]]*experimental-features[[:space:]]*=.*$/experimental-features = nix-command flakes/' "$NIX_CONF_FILE"
else
  printf "%s" "$NIX_FEATURES" >> "$NIX_CONF_FILE"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_DIR="${1:-$REPO_DEFAULT}"
[[ -f "$SCRIPT_DIR/flake.nix" ]] && REPO_DIR="$SCRIPT_DIR"

[[ -d "$REPO_DIR" ]] || die "Repo dir not found: $REPO_DIR"
[[ -f "$REPO_DIR/flake.nix" ]] || die "flake.nix not found in: $REPO_DIR"

# Generate current machine hardware config
HW_TMP="$(mktemp -t hardware-configuration.nix.XXXXXX)"
trap 'rm -f "$HW_TMP" || true' EXIT

info "Generating current machine hardware-configuration.nix..."
sudo nixos-generate-config --show-hardware-config > "$HW_TMP"
[[ -s "$HW_TMP" ]] || die "Failed to generate hardware-configuration.nix"

# Backup /etc/nixos
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP="/etc/nixos.backup-$TS"
if [[ -e /etc/nixos || -L /etc/nixos ]]; then
  info "Backing up /etc/nixos -> $BACKUP"
  sudo mv /etc/nixos "$BACKUP"
fi

if [[ "$MODE" == "copy" ]]; then
  info "MODE=copy: copying repo into /etc/nixos"
  sudo mkdir -p /etc/nixos
  if command -v rsync >/dev/null 2>&1; then
    sudo rsync -a --delete \
      --exclude '.git/' \
      --exclude '.github/' \
      --exclude '.direnv/' \
      --exclude 'result' \
      --exclude 'result-*' \
      --exclude '*.swp' \
      --exclude '.DS_Store' \
      "$REPO_DIR/" /etc/nixos/
  else
    nix --extra-experimental-features "nix-command flakes" \
      shell nixpkgs#rsync -c sudo rsync -a --delete "$REPO_DIR/" /etc/nixos/
  fi
  install -m 0644 "$HW_TMP" "$REPO_DIR/hardware-configuration.nix"
else
  info "MODE=link: linking /etc/nixos -> $REPO_DIR"
  sudo ln -sfn "$REPO_DIR" /etc/nixos
  install -m 0644 "$HW_TMP" "$REPO_DIR/hardware-configuration.nix"
fi

# Install helper: ~/.local/bin/rebuild (always uses HOME repo)
info "Installing helper: ~/.local/bin/rebuild"
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/rebuild" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec sudo env NIX_CONFIG=\$'experimental-features = nix-command flakes\n' \
  nixos-rebuild switch --flake "${REPO_DIR}#${FLAKE_HOST}" --accept-flake-config "\$@"
EOF
chmod +x "$HOME/.local/bin/rebuild"

grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.profile" 2>/dev/null || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"

info "Rebuilding from repo: ${REPO_DIR}#${FLAKE_HOST}"
sudo env NIX_CONFIG="$NIX_FEATURES" \
  nixos-rebuild switch --flake "${REPO_DIR}#${FLAKE_HOST}" --accept-flake-config

echo ""
echo "✅ Done."
echo "Repo:          $REPO_DIR"
echo "/etc/nixos:     $(readlink -f /etc/nixos || true)"
echo "Backup (old):  $BACKUP"
echo "Try anywhere:  rebuild"
echo ""
echo "Tip: if you exported NIX_CONFIG in your shell ранее, run: unset NIX_CONFIG"
