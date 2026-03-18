#!/usr/bin/env bash
# bootstrap.sh — First-boot installer for Nixos-Dots (prague / ivali)
#
# PROBLEM SOLVED:
#   A fresh NixOS install has no flakes. This script temporarily enables
#   them via NIX_CONFIG (environment variable — no file edits, no daemon
#   restart needed) long enough to run the first `nixos-rebuild switch`.
#   After the build your permanent nix.settings take over.
#
# USAGE:
#   # From an already-cloned repo:
#   bash bootstrap.sh
#
#   # Clone from GitHub first, then bootstrap:
#   bash bootstrap.sh --repo https://github.com/YOU/Nixos-Dots
#
#   # Clone to a custom path:
#   bash bootstrap.sh --repo https://github.com/YOU/Nixos-Dots --dir ~/my-dots
#
#   # Copy files into /etc/nixos instead of symlinking (air-gapped / CI):
#   MODE=copy bash bootstrap.sh
#
# OPTIONS:
#   --repo <url>   Git URL to clone (skipped if repo already exists locally)
#   --dir  <path>  Where to clone / look for the repo  (default: ~/Nixos-Dots)
#   --host <name>  Flake host to build               (default: prague)
#   --dry          Print what would happen; don't change anything

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Defaults
# ─────────────────────────────────────────────────────────────────────────────
FLAKE_HOST="prague"
REPO_DIR="$HOME/Nixos-Dots"
REPO_URL=""
MODE="${MODE:-link}"   # link | copy
DRY=0

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

step()  { echo -e "\n${CYAN}${BOLD}==> $*${RESET}"; }
ok()    { echo -e "${GREEN}    ✓ $*${RESET}"; }
warn()  { echo -e "${YELLOW}    ⚠ $*${RESET}"; }
die()   { echo -e "${RED}${BOLD}ERROR: $*${RESET}" >&2; exit 1; }
run()   {
  if (( DRY )); then
    echo -e "${YELLOW}    [dry] $*${RESET}"
  else
    "$@"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)  REPO_URL="${2:?'--repo requires a URL'}";  shift 2 ;;
    --dir)   REPO_DIR="${2:?'--dir requires a path'}";  shift 2 ;;
    --host)  FLAKE_HOST="${2:?'--host requires a name'}"; shift 2 ;;
    --dry)   DRY=1; shift ;;
    -h|--help)
      sed -n '3,25p' "$0"   # print the header comment
      exit 0 ;;
    *) die "Unknown option: $1  (try --help)" ;;
  esac
done

# ─────────────────────────────────────────────────────────────────────────────
# Pre-flight checks
# ─────────────────────────────────────────────────────────────────────────────
step "Pre-flight checks"

[[ "$(id -u)" -ne 0 ]] || die "Run as your normal user, not root."
command -v nix  >/dev/null 2>&1 || die "'nix' not found — are you on NixOS?"
command -v sudo >/dev/null 2>&1 || die "'sudo' not found."
command -v git  >/dev/null 2>&1 || {
  warn "'git' not in PATH — will try nix-shell fallback for clone."
  GIT_CMD="nix-shell -p git --run git"
}
GIT_CMD="${GIT_CMD:-git}"

# This is what allows flakes to be used right now on a fresh install.
# It is only active for this shell session; nothing is written to disk yet.
# Your final nix.settings.experimental-features makes it permanent after build.
export NIX_CONFIG=$'experimental-features = nix-command flakes\n'
ok "Flakes enabled for this session via NIX_CONFIG (no daemon restart needed)"

sudo -v   # cache sudo credentials early
ok "sudo credentials cached"

# ─────────────────────────────────────────────────────────────────────────────
# Locate / clone the repo
# ─────────────────────────────────────────────────────────────────────────────
step "Locating Nixos-Dots repo"

# If we're running the script from inside the repo already, use that location.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [[ -f "$SCRIPT_DIR/flake.nix" ]]; then
  REPO_DIR="$SCRIPT_DIR"
  ok "Detected repo at script location: $REPO_DIR"

elif [[ -n "$REPO_URL" ]]; then
  if [[ -d "$REPO_DIR/.git" ]]; then
    warn "Repo already exists at $REPO_DIR — skipping clone (using existing)"
  else
    step "Cloning $REPO_URL → $REPO_DIR"
    run $GIT_CMD clone "$REPO_URL" "$REPO_DIR"
  fi

elif [[ -d "$REPO_DIR" && -f "$REPO_DIR/flake.nix" ]]; then
  ok "Found existing repo at $REPO_DIR"

else
  die "No repo found at $REPO_DIR and no --repo URL given.\n" \
      "  Either:\n" \
      "    • Run this script from inside the cloned Nixos-Dots directory, or\n" \
      "    • Pass --repo https://github.com/YOU/Nixos-Dots"
fi

[[ -f "$REPO_DIR/flake.nix" ]]        || die "flake.nix not found in $REPO_DIR"
[[ -f "$REPO_DIR/configuration.nix" ]] || die "configuration.nix not found in $REPO_DIR"
ok "Repo looks valid: $REPO_DIR"

# ─────────────────────────────────────────────────────────────────────────────
# Generate hardware-configuration.nix for THIS machine
# ─────────────────────────────────────────────────────────────────────────────
step "Generating hardware-configuration.nix for this machine"

HW_TMP="$(mktemp -t hardware-configuration.nix.XXXXXX)"
trap 'rm -f "$HW_TMP" 2>/dev/null || true' EXIT

sudo nixos-generate-config --show-hardware-config > "$HW_TMP"
[[ -s "$HW_TMP" ]] || die "hardware-configuration.nix came out empty — check nixos-generate-config"

if [[ -f "$REPO_DIR/hardware-configuration.nix" ]]; then
  warn "Overwriting existing hardware-configuration.nix in repo"
fi
run install -m 0644 "$HW_TMP" "$REPO_DIR/hardware-configuration.nix"
ok "Written to $REPO_DIR/hardware-configuration.nix"

# ─────────────────────────────────────────────────────────────────────────────
# Point /etc/nixos at the repo
# ─────────────────────────────────────────────────────────────────────────────
step "Installing repo as /etc/nixos"

TS="$(date +%Y%m%d-%H%M%S)"
BACKUP="/etc/nixos.backup-$TS"

if [[ -e /etc/nixos || -L /etc/nixos ]]; then
  warn "Backing up existing /etc/nixos → $BACKUP"
  run sudo mv /etc/nixos "$BACKUP"
fi

if [[ "$MODE" == "copy" ]]; then
  step "MODE=copy: copying repo into /etc/nixos"
  run sudo mkdir -p /etc/nixos

  if command -v rsync >/dev/null 2>&1; then
    run sudo rsync -a --delete \
      --exclude '.git/' \
      --exclude '.github/' \
      --exclude '.direnv/' \
      --exclude 'result' \
      --exclude 'result-*' \
      --exclude '*.swp' \
      --exclude '.DS_Store' \
      "$REPO_DIR/" /etc/nixos/
  else
    # rsync not available yet on a fresh system — use nix shell
    run sudo env NIX_CONFIG="$NIX_CONFIG" \
      nix shell nixpkgs#rsync --command \
        rsync -a --delete "$REPO_DIR/" /etc/nixos/
  fi
  ok "/etc/nixos populated (copy mode)"
else
  run sudo ln -sfn "$REPO_DIR" /etc/nixos
  ok "/etc/nixos → $REPO_DIR  (symlink mode)"
fi

# Verify the flake is accessible through the new path
sudo test -f /etc/nixos/flake.nix || die "/etc/nixos/flake.nix not reachable after setup — check permissions"

# ─────────────────────────────────────────────────────────────────────────────
# Install the convenience 'rebuild' helper early
# (useful even if the build below fails — you can re-run manually)
# ─────────────────────────────────────────────────────────────────────────────
step "Installing ~/.local/bin/rebuild helper"

mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/rebuild" <<EOF
#!/usr/bin/env bash
# Thin wrapper: sudo nixos-rebuild switch with flakes enabled.
# Generated by bootstrap.sh on ${TS}.
set -euo pipefail
exec sudo env NIX_CONFIG=\$'experimental-features = nix-command flakes\n' \\
  nixos-rebuild switch \\
  --flake "${REPO_DIR}#${FLAKE_HOST}" \\
  --accept-flake-config "\$@"
EOF
chmod +x "$HOME/.local/bin/rebuild"
ok "~/.local/bin/rebuild installed"

# Make ~/.local/bin available in this session and future logins
export PATH="$HOME/.local/bin:$PATH"
grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.profile" 2>/dev/null || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"

# ─────────────────────────────────────────────────────────────────────────────
# THE BUILD — first nixos-rebuild switch
# ─────────────────────────────────────────────────────────────────────────────
step "Running first nixos-rebuild switch  →  ${REPO_DIR}#${FLAKE_HOST}"
echo -e "${YELLOW}    This will download and build your full configuration."
echo -e "    Go grab a coffee — this will take a while on first run. ☕${RESET}\n"

if (( DRY )); then
  warn "[dry] Would run: sudo nixos-rebuild switch --flake ${REPO_DIR}#${FLAKE_HOST}"
else
  sudo env NIX_CONFIG="$NIX_CONFIG" \
    nixos-rebuild switch \
      --flake "${REPO_DIR}#${FLAKE_HOST}" \
      --accept-flake-config
fi

# ─────────────────────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗"
echo -e "║  ✅  Bootstrap complete!                         ║"
echo -e "╚══════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${BOLD}Repo:${RESET}          $REPO_DIR"
echo -e "  ${BOLD}/etc/nixos:${RESET}    $(readlink -f /etc/nixos 2>/dev/null || echo '(copied)')"
[[ -e "$BACKUP" ]] && \
echo -e "  ${BOLD}Old config:${RESET}    $BACKUP"
echo ""
echo -e "  ${BOLD}Useful commands (available in your next shell):${RESET}"
echo -e "    rebuild          — nixos-rebuild switch (the usual)"
echo -e "    hms              — home-manager switch"
echo -e "    update           — update all flake inputs then rebuild"
echo -e "    uall             — update + rebuild + HM + GC"
echo ""
echo -e "  ${CYAN}Reboot recommended to fully activate the new kernel and GNOME session.${RESET}"
echo ""
