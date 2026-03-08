{ config, pkgs, lib, ... }:

let
  repoDir  = "${config.home.homeDirectory}/Nixos-Dots";
  host     = "prague";
  username = "ivali";
  flakeRef = "${repoDir}#${host}";
  hmRef    = "${repoDir}#${username}";

  maybePkg = name:
    if builtins.hasAttr name pkgs then
      let v = builtins.tryEval (builtins.getAttr name pkgs);
      in if v.success then [ v.value ] else [ ]
    else
      [ ];

  # ── Preferred apps with fallbacks ──────────────────────────────────────────
  chromePkg =
    if builtins.hasAttr "google-chrome" pkgs then pkgs.google-chrome
    else pkgs.chromium;

  libreOfficePkg =
    if builtins.hasAttr "libreoffice-fresh" pkgs then pkgs.libreoffice-fresh
    else pkgs.libreoffice;

  # ── Nerd fonts (compatible with `nerdfonts` OR `nerd-fonts`) ───────────────
  nerdFontPkgs =
    if builtins.hasAttr "nerdfonts" pkgs then
      [ (pkgs.nerdfonts.override { fonts = [ "FiraCode" "JetBrainsMono" "Meslo" "Hack" ]; }) ]
    else if builtins.hasAttr "nerd-fonts" pkgs then
      let
        nf = pkgs."nerd-fonts";
        maybeAttr = name:
          if builtins.hasAttr name nf then
            let v = builtins.tryEval (builtins.getAttr name nf);
            in if v.success then [ v.value ] else [ ]
          else [ ];
      in
        (maybeAttr "fira-code")
        ++ (maybeAttr "jetbrains-mono")
        ++ (maybeAttr "meslo-lg")
        ++ (maybeAttr "hack")
    else
      [ ];

  # ═══════════════════════════════════════════════════════════════════════════
  # Keyboard workflow scripts
  # ═══════════════════════════════════════════════════════════════════════════
  openFiles = pkgs.writeShellScriptBin "open-files" ''
    set -euo pipefail
    exec nautilus --new-window
  '';

  openTerminal = pkgs.writeShellScriptBin "open-terminal" ''
    set -euo pipefail
    exec kgx
  '';

  openChrome = pkgs.writeShellScriptBin "open-chrome" ''
    set -euo pipefail
    if command -v google-chrome-stable >/dev/null 2>&1; then exec google-chrome-stable; fi
    if command -v google-chrome        >/dev/null 2>&1; then exec google-chrome;        fi
    if command -v chromium             >/dev/null 2>&1; then exec chromium;             fi
    exit 0
  '';

  openVSCode = pkgs.writeShellScriptBin "open-vscode" ''
    set -euo pipefail
    # The `code` binary is the Wayland-native wrapper installed by vscode.nix
    if command -v code   >/dev/null 2>&1; then exec code;   fi
    if command -v codium >/dev/null 2>&1; then exec codium; fi
    exit 0
  '';

  killActiveWindow = pkgs.writeShellScriptBin "kill-active-window" ''
    set -euo pipefail
    ${pkgs.glib}/bin/gdbus call --session \
      --dest org.gnome.Shell \
      --object-path /org/gnome/Shell \
      --method org.gnome.Shell.Eval \
      "(() => { const w = global.display.get_focus_window(); if (!w) return 'no-window'; try { w.kill(); return 'killed'; } catch (e) { try { w.delete(global.get_current_time()); return 'closed'; } catch (e2) { return 'failed'; } } })()"
  '';

  rebootNow = pkgs.writeShellScriptBin "reboot-now" ''
    set -euo pipefail
    exec sudo ${pkgs.systemd}/bin/systemctl reboot --no-wall
  '';

  poweroffNow = pkgs.writeShellScriptBin "poweroff-now" ''
    set -euo pipefail
    exec sudo ${pkgs.systemd}/bin/systemctl poweroff --no-wall
  '';

  # ═══════════════════════════════════════════════════════════════════════════
  # Flake management scripts
  # ═══════════════════════════════════════════════════════════════════════════

  # Check flake for evaluation errors
  nixosFlakeCheck = pkgs.writeShellScriptBin "nixos-flake-check" ''
    set -euo pipefail
    echo "==> Checking flake in ${repoDir} …"
    cd "${repoDir}"
    ${pkgs.nix}/bin/nix flake check --accept-flake-config
  '';

  # Update ALL flake inputs to their latest revision
  nixosFlakeUpdate = pkgs.writeShellScriptBin "nixos-flake-update" ''
    set -euo pipefail
    echo "==> Updating all flake inputs in ${repoDir} …"
    cd "${repoDir}"
    ${pkgs.nix}/bin/nix flake update --accept-flake-config
    echo ""
    echo "==> flake.lock after update:"
    ${pkgs.git}/bin/git diff --stat HEAD -- flake.lock || true
    echo ""
    echo "==> Git status:"
    ${pkgs.git}/bin/git status --porcelain || true
  '';

  # Update a single named flake input  (usage: nixos-update-input nixpkgs)
  nixosUpdateInput = pkgs.writeShellScriptBin "nixos-update-input" ''
    set -euo pipefail
    if [[ $# -lt 1 ]]; then
      echo "Usage: nixos-update-input <input-name>"
      echo "Example: nixos-update-input nixpkgs"
      exit 1
    fi
    echo "==> Updating flake input: $1 …"
    cd "${repoDir}"
    ${pkgs.nix}/bin/nix flake update "$1" --accept-flake-config
    echo "==> Done. Run 'rebuild' to activate."
  '';

  # Show flake metadata / input revisions
  nixosShowInputs = pkgs.writeShellScriptBin "nixos-inputs" ''
    set -euo pipefail
    cd "${repoDir}"
    ${pkgs.nix}/bin/nix flake metadata --accept-flake-config
  '';

  # Show available flake outputs
  nixosShowOutputs = pkgs.writeShellScriptBin "nixos-outputs" ''
    set -euo pipefail
    cd "${repoDir}"
    ${pkgs.nix}/bin/nix flake show --accept-flake-config
  '';

  # ═══════════════════════════════════════════════════════════════════════════
  # NixOS rebuild scripts
  # ═══════════════════════════════════════════════════════════════════════════

  # Activate new config
  nixosSwitch = pkgs.writeShellScriptBin "nixos-switch" ''
    set -euo pipefail
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
      echo "==> This command requires sudo. You may be prompted for your password."
    fi
    echo "==> nixos-rebuild switch --flake ${flakeRef} …"
    sudo ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch \
      --flake "${flakeRef}" \
      --accept-flake-config "$@"
  '';

  # Build without activating
  nixosBuild = pkgs.writeShellScriptBin "nixos-build" ''
    set -euo pipefail
    echo "==> nixos-rebuild build --flake ${flakeRef} …"
    sudo ${pkgs.nixos-rebuild}/bin/nixos-rebuild build \
      --flake "${flakeRef}" \
      --accept-flake-config "$@"
  '';

  # Build and activate on next boot only
  nixosBoot = pkgs.writeShellScriptBin "nixos-boot" ''
    set -euo pipefail
    echo "==> nixos-rebuild boot --flake ${flakeRef} …"
    sudo ${pkgs.nixos-rebuild}/bin/nixos-rebuild boot \
      --flake "${flakeRef}" \
      --accept-flake-config "$@"
  '';

  # Dry-run: show derivations without building
  nixosDryRun = pkgs.writeShellScriptBin "nixos-dry" ''
    set -euo pipefail
    echo "==> nixos-rebuild dry-run --flake ${flakeRef} …"
    sudo ${pkgs.nixos-rebuild}/bin/nixos-rebuild dry-run \
      --flake "${flakeRef}" \
      --accept-flake-config "$@"
  '';

  # Build and test (activate temporarily, reverted on reboot)
  nixosTest = pkgs.writeShellScriptBin "nixos-test" ''
    set -euo pipefail
    echo "==> nixos-rebuild test --flake ${flakeRef} …"
    sudo ${pkgs.nixos-rebuild}/bin/nixos-rebuild test \
      --flake "${flakeRef}" \
      --accept-flake-config "$@"
  '';

  # Roll back to the previous generation
  nixosRollback = pkgs.writeShellScriptBin "nixos-rollback" ''
    set -euo pipefail
    echo "==> Rolling back to previous NixOS generation …"
    sudo ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --rollback
  '';

  # Diff current system vs what would be built
  nixosDiff = pkgs.writeShellScriptBin "nixos-diff" ''
    set -euo pipefail
    echo "==> Building to ./result for diff …"
    sudo ${pkgs.nixos-rebuild}/bin/nixos-rebuild build \
      --flake "${flakeRef}" \
      --accept-flake-config
    echo ""
    echo "==> Diff: current-system → result"
    ${pkgs.nix}/bin/nix store diff-closures /run/current-system ./result
  '';

  # List NixOS system generations
  nixosGenerations = pkgs.writeShellScriptBin "nixos-generations" ''
    set -euo pipefail
    echo "==> NixOS system generations:"
    sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
  '';

  # ═══════════════════════════════════════════════════════════════════════════
  # Full update pipeline
  # ═══════════════════════════════════════════════════════════════════════════

  # update inputs → check → switch
  nixosUpdate = pkgs.writeShellScriptBin "nixos-update" ''
    set -euo pipefail
    nixos-flake-update
    nixos-flake-check
    nixos-switch
  '';

  # update inputs → check → switch → home-manager → GC
  nixosUpgradeAll = pkgs.writeShellScriptBin "nixos-upgrade-all" ''
    set -euo pipefail
    echo "════════════════════════════════"
    echo " Full NixOS upgrade pipeline    "
    echo "════════════════════════════════"

    echo ""
    echo "── 1/4  Update flake inputs ───"
    nixos-flake-update

    echo ""
    echo "── 2/4  Check flake ───────────"
    nixos-flake-check

    echo ""
    echo "── 3/4  Rebuild & switch ──────"
    nixos-switch

    echo ""
    echo "── 4/4  Garbage collect ───────"
    sudo ${pkgs.nix}/bin/nix-collect-garbage -d || true
    sudo ${pkgs.nix}/bin/nix-store --optimise    || true

    echo ""
    echo "==> All done! System is up to date."
  '';

  # ═══════════════════════════════════════════════════════════════════════════
  # Garbage collection & store maintenance
  # ═══════════════════════════════════════════════════════════════════════════

  # Aggressive GC: delete ALL old generations (system + user profiles)
  nixosGC = pkgs.writeShellScriptBin "nixos-gc" ''
    set -euo pipefail
    echo "==> Collecting garbage (all old generations) …"
    sudo ${pkgs.nix}/bin/nix-collect-garbage -d
    ${pkgs.nix}/bin/nix-collect-garbage -d
    echo "==> Done."
  '';

  # Soft GC: keep generations newer than N days (default 14)
  nixosGCOld = pkgs.writeShellScriptBin "nixos-gc-old" ''
    set -euo pipefail
    DAYS="''${1:-14}"
    echo "==> Deleting generations older than ''${DAYS} days …"
    sudo ${pkgs.nix}/bin/nix-collect-garbage --delete-older-than "''${DAYS}d"
    ${pkgs.nix}/bin/nix-collect-garbage     --delete-older-than "''${DAYS}d"
    echo "==> Done."
  '';

  # Dry-run GC: show what WOULD be deleted without removing anything
  nixosGCDry = pkgs.writeShellScriptBin "nixos-gc-dry" ''
    set -euo pipefail
    echo "==> Dry-run GC (nothing will be deleted) …"
    sudo ${pkgs.nix}/bin/nix-collect-garbage -d --dry-run 2>&1 || true
    ${pkgs.nix}/bin/nix-collect-garbage     -d --dry-run 2>&1 || true
  '';

  # Hard-link identical files in /nix/store (saves disk space)
  nixosOptimise = pkgs.writeShellScriptBin "nixos-optimise" ''
    set -euo pipefail
    echo "==> Optimising nix store (hard-linking identical files) …"
    sudo ${pkgs.nix}/bin/nix-store --optimise
    echo "==> Done."
  '';

  # GC + optimise in one shot
  nixosClean = pkgs.writeShellScriptBin "nixos-clean" ''
    set -euo pipefail
    nixos-gc
    nixos-optimise
    echo "==> Store size:"
    du -sh /nix/store 2>/dev/null || true
  '';

  # Show disk usage of /nix/store
  nixosStoreSize = pkgs.writeShellScriptBin "nixos-store-size" ''
    set -euo pipefail
    echo "==> /nix/store usage:"
    du -sh /nix/store
    echo ""
    echo "==> Top 20 largest store paths:"
    du -sh /nix/store/* 2>/dev/null | sort -rh | head -20
  '';

  # ═══════════════════════════════════════════════════════════════════════════
  # Home Manager scripts
  # ═══════════════════════════════════════════════════════════════════════════

  # Apply home-manager config (standalone mode)
  hmSwitch = pkgs.writeShellScriptBin "hm-switch" ''
    set -euo pipefail
    echo "==> home-manager switch --flake ${hmRef} …"
    home-manager switch --flake "${hmRef}" "$@"
  '';

  # Build home-manager without activating
  hmBuild = pkgs.writeShellScriptBin "hm-build" ''
    set -euo pipefail
    echo "==> home-manager build --flake ${hmRef} …"
    home-manager build --flake "${hmRef}" "$@"
  '';

  # Show Home Manager release notes / changelog for current generation
  hmNews = pkgs.writeShellScriptBin "hm-news" ''
    set -euo pipefail
    home-manager news --flake "${hmRef}"
  '';

  # List packages managed by Home Manager
  hmPackages = pkgs.writeShellScriptBin "hm-packages" ''
    set -euo pipefail
    echo "==> Home Manager packages:"
    home-manager packages
  '';

  # List Home Manager generations
  hmGenerations = pkgs.writeShellScriptBin "hm-generations" ''
    set -euo pipefail
    echo "==> Home Manager generations:"
    home-manager generations
  '';

  # Remove old Home Manager generations (keeps current)
  hmGC = pkgs.writeShellScriptBin "hm-gc" ''
    set -euo pipefail
    echo "==> Removing old Home Manager generations …"
    home-manager expire-generations "-0 days"
    ${pkgs.nix}/bin/nix-collect-garbage
    echo "==> Done."
  '';

  # Roll back to the previous Home Manager generation
  hmRollback = pkgs.writeShellScriptBin "hm-rollback" ''
    set -euo pipefail
    PREV=$(home-manager generations | awk 'NR==2{print $NF}')
    if [[ -z "$PREV" ]]; then
      echo "No previous Home Manager generation found."
      exit 1
    fi
    echo "==> Activating previous HM generation: $PREV"
    "$PREV/activate"
  '';

  # ═══════════════════════════════════════════════════════════════════════════
  # Dev / formatting scripts
  # ═══════════════════════════════════════════════════════════════════════════

  nixosFormat = pkgs.writeShellScriptBin "nixos-format" ''
    set -euo pipefail
    echo "==> Formatting all .nix files in ${repoDir} …"
    find "${repoDir}" -name "*.nix" -type f \
      -exec ${pkgs.nixfmt}/bin/nixfmt {} \;
    echo "==> Done."
  '';

  nixosLint = pkgs.writeShellScriptBin "nixos-lint" ''
    set -euo pipefail
    echo "==> Parsing all .nix files in ${repoDir} …"
    find "${repoDir}" -name "*.nix" -type f \
      -exec ${pkgs.nix}/bin/nix-instantiate --parse {} \; > /dev/null
    echo "==> All files parsed OK."
  '';

  # ═══════════════════════════════════════════════════════════════════════════
  # GNOME custom keybinding paths
  # ═══════════════════════════════════════════════════════════════════════════
  kbBasePath = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings";
  kb0Path = "${kbBasePath}/custom0/";
  kb1Path = "${kbBasePath}/custom1/";
  kb2Path = "${kbBasePath}/custom2/";
  kb3Path = "${kbBasePath}/custom3/";
  kb4Path = "${kbBasePath}/custom4/";
  kb5Path = "${kbBasePath}/custom5/";
  kb6Path = "${kbBasePath}/custom6/";

  kbBaseKey = "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings";
  kb0Key = "${kbBaseKey}/custom0";
  kb1Key = "${kbBaseKey}/custom1";
  kb2Key = "${kbBaseKey}/custom2";
  kb3Key = "${kbBaseKey}/custom3";
  kb4Key = "${kbBaseKey}/custom4";
  kb5Key = "${kbBaseKey}/custom5";
  kb6Key = "${kbBaseKey}/custom6";

  # ═══════════════════════════════════════════════════════════════════════════
  # Shell aliases injected into ~/.zshrc
  # ═══════════════════════════════════════════════════════════════════════════
  aliasesText = ''
    # ── Navigation ─────────────────────────────────────────────────────────
    alias cfg='cd ${repoDir}'
    alias edit-cfg='code ${repoDir}'

    # ── ls / shell utilities ────────────────────────────────────────────────
    alias ll='eza -lah --icons'
    alias ls='eza --icons'
    alias ff='fastfetch'

    # ── App launchers ───────────────────────────────────────────────────────
    alias files='open-files'
    alias term='open-terminal'
    alias chrome='open-chrome'
    alias vsc='open-vscode'

    # ── Flake management ────────────────────────────────────────────────────
    alias fu='nixos-flake-update'        # update all flake inputs
    alias fui='nixos-update-input'       # update a single input:  fui nixpkgs
    alias fcheck='nixos-flake-check'     # evaluate & check flake
    alias inputs='nixos-inputs'          # show input revisions
    alias outputs='nixos-outputs'        # show flake outputs

    # ── NixOS rebuild ───────────────────────────────────────────────────────
    alias rebuild='nixos-switch'         # build + activate
    alias nb='nixos-build'               # build only (no activate)
    alias nboot='nixos-boot'             # activate on next boot
    alias ntest='nixos-test'             # activate temporarily
    alias ndry='nixos-dry'               # dry-run (show derivations)
    alias ndiff='nixos-diff'             # diff current vs new closure
    alias ngen='nixos-generations'       # list system generations
    alias nroll='nixos-rollback'         # roll back to previous gen
    alias nfmt='nixos-format'            # nixfmt all .nix files
    alias nlint='nixos-lint'             # nix-instantiate --parse all

    # ── Full update pipelines ───────────────────────────────────────────────
    alias update='nixos-update'          # update inputs → check → switch
    alias uall='nixos-upgrade-all'       # update → check → switch → HM → GC

    # ── Garbage collection & store maintenance ──────────────────────────────
    alias gc='nixos-gc'                  # delete ALL old generations
    alias gcold='nixos-gc-old'           # delete gens older than N days (default 14)
    alias gcdry='nixos-gc-dry'           # dry-run GC (show what would go)
    alias opt='nixos-optimise'           # hard-link identical store files
    alias clean='nixos-clean'            # gc + optimise
    alias storesize='nixos-store-size'   # show /nix/store disk usage

    # ── Home Manager ────────────────────────────────────────────────────────
    alias hms='hm-switch'                # apply home-manager config
    alias hmb='hm-build'                 # build HM without activating
    alias hmnews='hm-news'               # show HM release notes
    alias hmpkgs='hm-packages'           # list HM-managed packages
    alias hmgen='hm-generations'         # list HM generations
    alias hmgc='hm-gc'                   # remove old HM generations
    alias hmroll='hm-rollback'           # roll back HM to previous gen
  '';
in
{
  # Pull VS Code config (extensions, settings, keybindings, LSP backends)
  # from its own module to keep this file manageable.
  imports = [ ./vscode.nix ];

  home.username = "ivali";
  home.homeDirectory = "/home/ivali";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
  xdg.enable = true;
  home.sessionPath = [ "$HOME/.local/bin" ];
  home.sessionVariables = {
    EDITOR = "vim";
    VISUAL = "code";
  };

  # Put your repo p10k into ~/.p10k.zsh
  home.file.".p10k.zsh".source = ./p10k.zsh;

  # Manage ~/.zshrc directly (NO programs.zsh module)
  home.file.".zshrc".text = ''
    # Managed by Home Manager – do not edit by hand
    # Suppress fastfetch with:  NO_FASTFETCH=1 zsh
    if [[ -o interactive ]] && [[ -z "''${NO_FASTFETCH:-}" ]] && command -v fastfetch >/dev/null 2>&1; then
      fastfetch
    fi

    ${aliasesText}

    # Powerlevel10k
    if [[ -r "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme" ]]; then
      source "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme"
    fi
    [[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
  '';

  # ── Fonts ─────────────────────────────────────────────────────────────────
  fonts.fontconfig.enable = true;
  home.activation.refreshFontCache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.fontconfig}/bin/fc-cache -r >/dev/null 2>&1 || true
  '';

  # ── GNOME keybindings via dconf ───────────────────────────────────────────
  dconf.enable = true;
  dconf.settings = {
    "org/gnome/shell" = { development-tools = true; };
    "org/gnome/desktop/wm/keybindings" = {
      close = [ "<Super>q" "<Alt>F4" ];
    };

    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [ kb0Path kb1Path kb2Path kb3Path kb4Path kb5Path kb6Path ];
    };

    "${kb0Key}" = { name = "Files";                command = "${openFiles}/bin/open-files";               binding = "<Super>e";      };
    "${kb1Key}" = { name = "Terminal";             command = "${openTerminal}/bin/open-terminal";         binding = "<Control>period"; };
    "${kb2Key}" = { name = "Chrome";               command = "${openChrome}/bin/open-chrome";             binding = "<Control>b";    };
    "${kb3Key}" = { name = "VS Code";              command = "${openVSCode}/bin/open-vscode";             binding = "<Super>c";      };
    "${kb4Key}" = { name = "Kill focused window";  command = "${killActiveWindow}/bin/kill-active-window"; binding = "<Super>Escape"; };
    "${kb5Key}" = { name = "Reboot NOW";           command = "${rebootNow}/bin/reboot-now";               binding = "<Super>z";      };
    "${kb6Key}" = { name = "Shutdown NOW";         command = "${poweroffNow}/bin/poweroff-now";           binding = "<Super>x";      };
  };

  # ── Packages ──────────────────────────────────────────────────────────────
  home.packages =
    (with pkgs; [
      # Shell / prompt
      zsh-powerlevel10k
      fastfetch
      nixfmt

      # CLI utilities
      eza bat fd ripgrep fzf zoxide nvd

      # GUI apps
      chromePkg
      libreOfficePkg

      github-desktop
      bruno
      dbeaver-bin
      filezilla
      meld
      flameshot

      gnome-extension-manager
      gnome-tweaks

      thunderbird
      obsidian
      vlc
      remmina

      # ── Keyboard helpers ─────────────────────────────────────────────────
      openFiles
      openTerminal
      openChrome
      openVSCode
      killActiveWindow
      rebootNow
      poweroffNow

      # ── Flake management ─────────────────────────────────────────────────
      nixosFlakeCheck
      nixosFlakeUpdate
      nixosUpdateInput
      nixosShowInputs
      nixosShowOutputs

      # ── NixOS rebuild ────────────────────────────────────────────────────
      nixosSwitch
      nixosBuild
      nixosBoot
      nixosDryRun
      nixosTest
      nixosRollback
      nixosDiff
      nixosGenerations

      # ── Full update pipelines ────────────────────────────────────────────
      nixosUpdate
      nixosUpgradeAll

      # ── Garbage collection & store ───────────────────────────────────────
      nixosGC
      nixosGCOld
      nixosGCDry
      nixosOptimise
      nixosClean
      nixosStoreSize

      # ── Home Manager ─────────────────────────────────────────────────────
      hmSwitch
      hmBuild
      hmNews
      hmPackages
      hmGenerations
      hmGC
      hmRollback

      # ── Dev / formatting ─────────────────────────────────────────────────
      nixosFormat
      nixosLint
    ])
    ++ nerdFontPkgs
    ++ maybePkg "podman-desktop"
    ++ maybePkg "gitkraken"
    ++ maybePkg "drawio"
    ++ maybePkg "insomnia"
    ++ maybePkg "postman"
    ;
}
