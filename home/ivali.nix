{ config, pkgs, lib, ... }:

let
  repoDir  = "${config.home.homeDirectory}/Nixos-Dots";
  host     = "prague";
  flakeRef = "${repoDir}#${host}";

  maybePkg = name:
    if builtins.hasAttr name pkgs then
      let v = builtins.tryEval (builtins.getAttr name pkgs);
      in if v.success then [ v.value ] else [ ]
    else
      [ ];

  # Preferred apps with fallback
  vsCodePkg =
    if builtins.hasAttr "vscode" pkgs then pkgs.vscode
    else if builtins.hasAttr "vscodium" pkgs then pkgs.vscodium
    else pkgs.vim;

  chromePkg =
    if builtins.hasAttr "google-chrome" pkgs then pkgs.google-chrome
    else pkgs.chromium;

  libreOfficePkg =
    if builtins.hasAttr "libreoffice-fresh" pkgs then pkgs.libreoffice-fresh
    else pkgs.libreoffice;

  # Nerd fonts (compatible with `nerdfonts` OR `nerd-fonts`)
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
          else
            [ ];
      in
        (maybeAttr "fira-code")
        ++ (maybeAttr "jetbrains-mono")
        ++ (maybeAttr "meslo-lg")
        ++ (maybeAttr "hack")
    else
      [ ];

  # -------------------------
  # Keyboard workflow scripts
  # -------------------------
  openFiles = pkgs.writeShellScriptBin "open-files" ''
    set -euo pipefail
    exec nautilus --new-window
  '';

  # GNOME Console = kgx
  openTerminal = pkgs.writeShellScriptBin "open-terminal" ''
    set -euo pipefail
    exec kgx
  '';

  openChrome = pkgs.writeShellScriptBin "open-chrome" ''
    set -euo pipefail
    if command -v google-chrome-stable >/dev/null 2>&1; then exec google-chrome-stable; fi
    if command -v google-chrome >/dev/null 2>&1; then exec google-chrome; fi
    if command -v chromium >/dev/null 2>&1; then exec chromium; fi
    exit 0
  '';

  openVSCode = pkgs.writeShellScriptBin "open-vscode" ''
    set -euo pipefail
    if command -v code >/dev/null 2>&1; then exec code; fi
    if command -v codium >/dev/null 2>&1; then exec codium; fi
    exit 0
  '';

  # Wayland-safe kill focused window via GNOME Shell Eval
  killActiveWindow = pkgs.writeShellScriptBin "kill-active-window" ''
    set -euo pipefail
    ${pkgs.glib}/bin/gdbus call --session \
      --dest org.gnome.Shell \
      --object-path /org/gnome/Shell \
      --method org.gnome.Shell.Eval \
      "(() => { const w = global.display.get_focus_window(); if (!w) return 'no-window'; try { w.kill(); return 'killed'; } catch (e) { try { w.delete(global.get_current_time()); return 'closed'; } catch (e2) { return 'failed'; } } })()"
  '';

  # Requires sudo NOPASSWD rules (in modules/security.nix)
  rebootNow = pkgs.writeShellScriptBin "reboot-now" ''
    set -euo pipefail
    exec sudo ${pkgs.systemd}/bin/systemctl reboot --no-wall
  '';

  poweroffNow = pkgs.writeShellScriptBin "poweroff-now" ''
    set -euo pipefail
    exec sudo ${pkgs.systemd}/bin/systemctl poweroff --no-wall
  '';

  # -------------------------
  # GNOME custom keybinding paths
  # IMPORTANT:
  # - list entries MUST be "/org/.../custom0/"
  # - dconf.settings keys MUST be "org/.../custom0" (no leading slash)
  # -------------------------
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

  # -------------------------
  # Flake lifecycle helpers
  # -------------------------
  nixosFlakeCheck = pkgs.writeShellScriptBin "nixos-flake-check" ''
    set -euo pipefail
    cd "${repoDir}"
    ${pkgs.nix}/bin/nix flake check --accept-flake-config
  '';

  nixosFlakeUpdate = pkgs.writeShellScriptBin "nixos-flake-update" ''
    set -euo pipefail
    cd "${repoDir}"
    ${pkgs.nix}/bin/nix flake update --accept-flake-config
    echo ""
    echo "==> Updated flake.lock. Git status:"
    ${pkgs.git}/bin/git status --porcelain || true
  '';

  nixosSwitch = pkgs.writeShellScriptBin "nixos-switch" ''
    set -euo pipefail
    sudo ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch \
      --flake "${flakeRef}" \
      --accept-flake-config "$@"
  '';

  nixosUpdate = pkgs.writeShellScriptBin "nixos-update" ''
    set -euo pipefail
    nixos-flake-update
    nixos-flake-check
    nixos-switch
  '';

  nixosUpgradeAll = pkgs.writeShellScriptBin "nixos-upgrade-all" ''
    set -euo pipefail
    nixos-update
    echo ""
    echo "==> Cleanup"
    sudo nix-collect-garbage -d || true
    sudo nix-store --optimise || true
  '';

  nixosShowInputs = pkgs.writeShellScriptBin "nixos-inputs" ''
    set -euo pipefail
    cd "${repoDir}"
    ${pkgs.nix}/bin/nix flake metadata --accept-flake-config
  '';

  aliasesText = ''
    alias cfg='cd ${repoDir}'
    alias rebuild='nixos-switch'
    alias check='nixos-flake-check'
    alias fu='nixos-flake-update'
    alias update='nixos-update'
    alias uall='nixos-upgrade-all'
    alias inputs='nixos-inputs'

    alias files='open-files'
    alias term='open-terminal'
    alias chrome='open-chrome'
    alias vsc='open-vscode'

    alias ll='eza -lah --icons'
    alias ls='eza --icons'
    alias ff='fastfetch'
  '';

in
{
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
    # Managed by Home Manager
    # fastfetch: disable with NO_FASTFETCH=1
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

  # Fonts
  fonts.fontconfig.enable = true;
  home.activation.refreshFontCache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.fontconfig}/bin/fc-cache -r >/dev/null 2>&1 || true
  '';

  # GNOME keybindings via dconf
  dconf.enable = true;
  dconf.settings = {
    "org/gnome/shell" = { development-tools = true; };

    # Super+Q closes window (keep Alt+F4)
    "org/gnome/desktop/wm/keybindings" = {
      close = [ "<Super>q" "<Alt>F4" ];
    };

    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [ kb0Path kb1Path kb2Path kb3Path kb4Path kb5Path kb6Path ];
    };

    # Objects: NOTE no leading slash here (this fixes your error)
    "${kb0Key}" = { name = "Files"; command = "${openFiles}/bin/open-files"; binding = "<Super>e"; };
    "${kb1Key}" = { name = "Terminal (GNOME Console)"; command = "${openTerminal}/bin/open-terminal"; binding = "<Control>period"; };
    "${kb2Key}" = { name = "Chrome"; command = "${openChrome}/bin/open-chrome"; binding = "<Control>b"; };
    "${kb3Key}" = { name = "VS Code"; command = "${openVSCode}/bin/open-vscode"; binding = "<Super>c"; };
    "${kb4Key}" = { name = "Kill focused window"; command = "${killActiveWindow}/bin/kill-active-window"; binding = "<Super>Escape"; };
    "${kb5Key}" = { name = "Reboot NOW"; command = "${rebootNow}/bin/reboot-now"; binding = "<Super>z"; };
    "${kb6Key}" = { name = "Shutdown NOW"; command = "${poweroffNow}/bin/poweroff-now"; binding = "<Super>x"; };
  };

  home.packages =
    (with pkgs; [
      zsh-powerlevel10k
      fastfetch

      eza bat fd ripgrep fzf zoxide nvd

      chromePkg
      vsCodePkg
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

      openFiles
      openTerminal
      openChrome
      openVSCode
      killActiveWindow
      rebootNow
      poweroffNow

      nixosFlakeUpdate
      nixosFlakeCheck
      nixosSwitch
      nixosUpdate
      nixosUpgradeAll
      nixosShowInputs
    ])
    ++ nerdFontPkgs
    ++ maybePkg "podman-desktop"
    ++ maybePkg "gitkraken"
    ++ maybePkg "drawio"
    ++ maybePkg "insomnia"
    ++ maybePkg "postman"
    ;
}
