# testing.nix
# ─────────────────────────────────────────────────────────────────────────────
# A nix-shell environment for quickly trialling packages — free OR unfree.
#
# USAGE
# ──────
#   Default (uses packages listed below):
#     nix-shell testing.nix
#
#   One-liner (inline, no file needed):
#     nix-shell -p stremio-linux-shell --impure
#     NIXPKGS_ALLOW_UNFREE=1 nix-shell -p stremio-linux-shell --impure
#
#   With this file (recommended — handles unfree automatically):
#     nix-shell testing.nix
#
#   Override packages at the command line:
#     nix-shell testing.nix --arg extraPackages '[ pkgs.vlc pkgs.stremio ]'
#
# ADDING PACKAGES
# ────────────────
#   Free package:    add  pkgs.curl  to the `packages` list below.
#   Unfree package:  add  pkgs.stremio-linux-shell  — allowUnfree handles it.
# ─────────────────────────────────────────────────────────────────────────────

{ extraPackages ? [ ] }:

let
  # ── Nixpkgs with unfree packages unlocked ───────────────────────────────
  pkgs = import <nixpkgs> {
    config = {
      # Allow ALL unfree packages (simplest for a scratch/testing shell)
      allowUnfree = true;

      # ── Alternatively: allowlist only specific unfree packages ──────────
      # Comment out allowUnfree above and uncomment this block instead:
      #
      # allowUnfreePredicate = pkg:
      #   builtins.elem (pkgs.lib.getName pkg) [
      #     "stremio-linux-shell"
      #     "discord"
      #     "slack"
      #   ];
    };
  };

  # ── Packages to drop into the shell ─────────────────────────────────────
  # Add anything here — free or unfree — and it will just work.
  packages = with pkgs; [

    # ── Media / Streaming ────────────────────────────────────────────────
    stremio-linux-shell       # unfree — works because allowUnfree = true above

    # ── Utilities (free — uncomment as needed) ───────────────────────────
    # curl
    # wget
    # jq
    # htop
    # ffmpeg
    # vlc
    # mpv

    # ── Add your test packages below this line ───────────────────────────

  ] ++ extraPackages;  # also picks up any --arg extraPackages passed on CLI

in
pkgs.mkShell {
  name = "pkg-test-shell";

  buildInputs = packages;

  shellHook = ''
    echo ""
    echo "  ╔══════════════════════════════════════════════╗"
    echo "  ║       willis@prague — pkg test shell         ║"
    echo "  ║  unfree: allowed  │  exit: Ctrl-D or 'exit' ║"
    echo "  ╚══════════════════════════════════════════════╝"
    echo ""
    echo "  Loaded packages:"
    ${pkgs.lib.concatMapStringsSep "\n"
        (p: "  echo '    • ${p.name or (builtins.toString p)}'")
        packages}
    echo ""
  '';
}
