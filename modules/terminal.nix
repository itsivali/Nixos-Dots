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
  # FISH — interactive default shell
  ############################################################
  programs.fish = {
    enable = true;

    # ── Vendor fish plugin files from packages in environment.systemPackages ─
    # programs.fish.vendor.{config,completions,functions}.enable are all true
    # by default — fish picks up plugin files from any package in the system
    # path automatically.  Plugin packages are listed under systemPackages below.

    # ── Runs in every fish session (interactive + non-interactive) ─────────
    shellInit = ''
      # Core environment
      set -gx EDITOR   vim
      set -gx VISUAL   code
      set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
      set -g  fish_greeting ""

      fish_add_path --prepend "$HOME/.local/bin"
    '';

    # ── Runs only in interactive sessions ──────────────────────────────────
    interactiveShellInit = ''
      # ── Tide prompt configuration (p10k Rainbow / Lean style) ─────────────
      # set -U writes to universal variables (~/.config/fish/fish_variables)
      # so these survive across sessions without re-running `tide configure`.
      set -U tide_left_prompt_items   pwd git newline character
      set -U tide_right_prompt_items  status cmd_duration jobs node python rustc go java php time

      set -U tide_pwd_color_anchors          brblue
      set -U tide_pwd_color_dirs             blue
      set -U tide_pwd_color_truncated_dirs   brblack
      set -U tide_pwd_unwritable_icon        

      set -U tide_git_color_branch           brgreen
      set -U tide_git_color_staged           bryellow
      set -U tide_git_color_dirty            brred
      set -U tide_git_color_untracked        cyan
      set -U tide_git_color_operation        brred
      set -U tide_git_icon                  

      set -U tide_character_icon             ❯
      set -U tide_character_color            brgreen
      set -U tide_character_color_failure    brred
      set -U tide_character_vi_icon_default  ❮
      set -U tide_character_vi_icon_replace  ▶
      set -U tide_character_vi_icon_visual   V

      set -U tide_prompt_add_newline_before  true
      set -U tide_prompt_min_cols            34
      set -U tide_prompt_pad_items           true

      # ── fzf options ───────────────────────────────────────────────────────
      set -gx FZF_DEFAULT_OPTS "--height 40% --layout=reverse --border --info=inline"
      set -gx FZF_CTRL_R_OPTS  "--preview 'echo {}' --preview-window=down:3:wrap"

      # ── zoxide (smarter cd) ───────────────────────────────────────────────
      if command -q zoxide
        ${pkgs.zoxide}/bin/zoxide init fish | source
      end

      # ── fastfetch on login ────────────────────────────────────────────────
      if status is-login
        and test -z "$NO_FASTFETCH"
        and command -q fastfetch
        fastfetch
      end

    # ── Abbreviations (expand on Tab, visible in command line) ───────────
    # NOTE: Abbreviations are declared in programs.fish.shellAbbrs below,
    # not here, to avoid "abbreviation already exists" errors on every
    # session re-open (fish 3.6+ errors on duplicate universal abbrs).
  '';

  # ── Abbreviations — declared here so NixOS handles idempotency ────────
  # These are written as universal abbreviations by the fish module and
  # are not re-added on every session, preventing the fish 3.6+ duplicate error.
  shellAbbrs = {
    # Navigation
    cfg       = "cd ~/Nixos-Dots";
    edit-cfg  = "code ~/Nixos-Dots";
    ll        = "eza -lah --icons";
    ls        = "eza --icons";
    ff        = "fastfetch";

    # App launchers
    files  = "open-files";
    term   = "open-terminal";
    chrome = "open-chrome";
    vsc    = "open-vscode";

    # Flake management
    fu      = "nixos-flake-update";
    fui     = "nixos-update-input";
    fcheck  = "nixos-flake-check";
    inputs  = "nixos-inputs";
    outputs = "nixos-outputs";

    # NixOS rebuild
    rebuild  = "nixos-switch";
    nb       = "nixos-build";
    nboot    = "nixos-boot";
    ntest    = "nixos-test";
    ndry     = "nixos-dry";
    ndiff    = "nixos-diff";
    ngen     = "nixos-generations";
    nroll    = "nixos-rollback";
    nfmt     = "nixos-format";
    nlint    = "nixos-lint";

    # Full update pipelines
    update  = "nixos-update";
    uall    = "nixos-upgrade-all";

    # Garbage collection & store
    gc        = "nixos-gc";
    gcold     = "nixos-gc-old";
    gcdry     = "nixos-gc-dry";
    opt       = "nixos-optimise";
    clean     = "nixos-clean";
    storesize = "nixos-store-size";

    # Home Manager
    hms     = "hm-switch";
    hmb     = "hm-build";
    hmnews  = "hm-news";
    hmpkgs  = "hm-packages";
    hmgen   = "hm-generations";
    hmgc    = "hm-gc";
    hmroll  = "hm-rollback";
  };
};

  ############################################################
  # ZSH — retained: scripting, history & personal preference
  ############################################################
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    histSize = 100000;
    histFile  = "$HOME/.zsh_history";

    # Written into /etc/zshrc — applies system-wide
    shellInit = ''
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

      # ── Ctrl-R → fzf history search ───────────────────────────────────────
      if command -v fzf >/dev/null 2>&1; then
        source <(fzf --zsh 2>/dev/null || true)
      fi

      # ── zoxide (z command) ────────────────────────────────────────────────
      if command -v zoxide >/dev/null 2>&1; then
        eval "$(zoxide init zsh)"
      fi

      # ── Powerlevel10k is sourced per-user via home/ivali.nix (~/.zshrc) ───
      # Not sourced here so each user's ~/.p10k.zsh config is picked up correctly.
    '';
  };

  ############################################################
  # PACKAGES — available to both shells system-wide
  ############################################################
  environment.systemPackages = with pkgs; [
    fish
    zsh
    zsh-powerlevel10k       # sourced in home/ivali.nix for zsh

    # ── Fish plugins (vendored automatically by programs.fish.vendor.*) ────
    # NixOS installs their conf.d / functions / completions into the fish
    # data path so no fisher or runtime bootstrap is needed.
    fishPlugins.tide        # p10k-style async prompt
    fishPlugins.fzf-fish    # Ctrl-R history, Ctrl-T file, Alt-C cd
    # fishPlugins.z removed — zoxide already provides the `z` command;
    # having both causes a conflicting `z` function definition.
    # fishPlugins.async-prompt removed — tide has its own async prompt
    # rendering; async-prompt wraps it in a second async layer that never
    # resolves, causing the terminal to hang on the first prompt render.
    fishPlugins.pisces      # auto-close brackets and quotes

    eza                     # modern ls  (ll / ls aliases)
    bat                     # modern cat + MANPAGER
    fd                      # fast find
    ripgrep                 # fast grep
    fzf                     # fuzzy finder  (Ctrl-R in both shells)
    zoxide                  # smart cd  (z)
    fastfetch               # system info on login

    nixfmt        # nix formatter  (nfmt alias)
    nvd                     # nix closure diff
  ];
}
