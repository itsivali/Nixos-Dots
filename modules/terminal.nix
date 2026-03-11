{ config, pkgs, lib, ... }:

{
  ############################################################
  # DCONF (required by GNOME / home-manager dconf settings)
  ############################################################
  programs.dconf.enable = true;

  ############################################################
  # POLKIT — passwordless reboot/shutdown for wheel group
  ############################################################
  security.polkit.enable = true;
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (!subject.isInGroup("wheel")) return null;

      if (action.id == "org.freedesktop.login1.reboot" ||
          action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
          action.id == "org.freedesktop.login1.power-off" ||
          action.id == "org.freedesktop.login1.power-off-multiple-sessions") {
        return polkit.Result.YES;
      }

      return null;
    });
  '';

  ############################################################
  # ZSH — default interactive shell
  ############################################################
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    histSize = 100000;
    histFile  = "$HOME/.zsh_history";

    # Written into /etc/zshrc — applies system-wide
    shellInit = ''
      # ── Core environment ──────────────────────────────────────────────────
      export EDITOR="vim"
      export VISUAL="code"
      export MANPAGER="sh -c 'col -bx | bat -l man -p'"

      export PATH="$HOME/.local/bin:$PATH"

      # ── History options ───────────────────────────────────────────────────
      setopt HIST_IGNORE_ALL_DUPS     # remove older duplicate before saving
      setopt HIST_IGNORE_SPACE        # skip lines starting with a space
      setopt HIST_REDUCE_BLANKS       # strip extra whitespace
      setopt HIST_SAVE_NO_DUPS        # no duplicates in the file
      setopt SHARE_HISTORY            # share across concurrent shells
      setopt INC_APPEND_HISTORY_TIME  # append with timestamps; never overwrite
      setopt EXTENDED_HISTORY         # save  : <start>:<elapsed>;<command>

      # ── Up/Down arrow = prefix history search ─────────────────────────────
      autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
      zle -N up-line-or-beginning-search
      zle -N down-line-or-beginning-search
      bindkey "^[[A" up-line-or-beginning-search
      bindkey "^[[B" down-line-or-beginning-search
      bindkey "^[OA" up-line-or-beginning-search
      bindkey "^[OB" down-line-or-beginning-search

      # ── fzf — Ctrl-R history, Ctrl-T file, Alt-C cd ──────────────────────
      export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --info=inline"
      export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window=down:3:wrap"
      if command -v fzf >/dev/null 2>&1; then
        source <(fzf --zsh 2>/dev/null || true)
      fi

      # ── zoxide (z command) ────────────────────────────────────────────────
      if command -v zoxide >/dev/null 2>&1; then
        eval "$(zoxide init zsh)"
      fi

      # ── Powerlevel10k prompt ──────────────────────────────────────────────
      # ~/.p10k.zsh is sourced per-user via home/ivali.nix
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme

      # ── Syntax highlighting (must be near end of shellInit) ───────────────
      source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

      # ── Autosuggestions ───────────────────────────────────────────────────
      source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
      export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
      bindkey "^[[C" forward-char          # Right arrow accepts one char
      bindkey "^[f"  forward-word          # Alt-F accepts one word

      # ── fastfetch on every interactive terminal open ───────────────────────
      if [[ $- == *i* ]] && [[ -z "$NO_FASTFETCH" ]] && command -v fastfetch >/dev/null 2>&1; then
        fastfetch
      fi

      # ── Abbreviation-style aliases (zsh has no native abbrs; use aliases) ─

      # Navigation
      alias cfg="cd ~/Nixos-Dots"
      alias edit-cfg="code ~/Nixos-Dots"
      alias ll="eza -lah --icons"
      alias ls="eza --icons"
      alias ff="fastfetch"

      # App launchers
      alias files="open-files"
      alias term="open-terminal"
      alias chrome="open-chrome"
      alias vsc="open-vscode"

      # Flake management
      alias fu="nixos-flake-update"
      alias fui="nixos-update-input"
      alias fcheck="nixos-flake-check"
      alias inputs="nixos-inputs"
      alias outputs="nixos-outputs"

      # NixOS rebuild
      alias rebuild="nixos-switch"
      alias nb="nixos-build"
      alias nboot="nixos-boot"
      alias ntest="nixos-test"
      alias ndry="nixos-dry"
      alias ndiff="nixos-diff"
      alias ngen="nixos-generations"
      alias nroll="nixos-rollback"
      alias nfmt="nixos-format"
      alias nlint="nixos-lint"

      # Full update pipelines
      alias update="nixos-update"
      alias uall="nixos-upgrade-all"

      # Garbage collection & store
      alias gc="nixos-gc"
      alias gcold="nixos-gc-old"
      alias gcdry="nixos-gc-dry"
      alias opt="nixos-optimise"
      alias clean="nixos-clean"
      alias storesize="nixos-store-size"

      # Home Manager
      alias hms="hm-switch"
      alias hmb="hm-build"
      alias hmnews="hm-news"
      alias hmpkgs="hm-packages"
      alias hmgen="hm-generations"
      alias hmgc="hm-gc"
      alias hmroll="hm-rollback"
    '';
  };

  # Set zsh as the default login shell system-wide
  users.defaultUserShell = pkgs.zsh;

  ############################################################
  # PACKAGES — available system-wide
  ############################################################
  environment.systemPackages = with pkgs; [
    zsh
    zsh-powerlevel10k           # async p10k-style prompt
    zsh-syntax-highlighting     # fish-like command colouring
    zsh-autosuggestions         # fish-like inline history suggestions

    eza                         # modern ls  (ll / ls aliases)
    bat                         # modern cat + MANPAGER
    fd                          # fast find
    ripgrep                     # fast grep
    fzf                         # fuzzy finder  (Ctrl-R / Ctrl-T / Alt-C)
    zoxide                      # smart cd  (z)
    fastfetch                   # system info on every terminal open

    nixfmt                      # nix formatter  (nfmt alias)
    nvd                         # nix closure diff
  ];
}
