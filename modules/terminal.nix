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

    # ── Plugins resolved at build time — no fisher/curl needed at runtime ──
    plugins = [
      # Tide: async p10k-style prompt for fish
      { name = "tide";         src = pkgs.fishPlugins.tide.src; }
      # fzf key-bindings: Ctrl-R history, Ctrl-T file, Alt-C cd
      { name = "fzf-fish";     src = pkgs.fishPlugins.fzf-fish.src; }
      # z — fast directory jumping (like zoxide)
      { name = "z";            src = pkgs.fishPlugins.z.src; }
      # Async prompt rendering (keeps input snappy during slow git ops)
      { name = "async-prompt"; src = pkgs.fishPlugins.async-prompt.src; }
      # Auto-close brackets and quotes
      { name = "pisces";       src = pkgs.fishPlugins.pisces.src; }
    ];

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

      # Navigation
      abbr --add cfg       'cd ~/Nixos-Dots'
      abbr --add edit-cfg  'code ~/Nixos-Dots'
      abbr --add ll        'eza -lah --icons'
      abbr --add ls        'eza --icons'
      abbr --add ff        'fastfetch'

      # App launchers
      abbr --add files  'open-files'
      abbr --add term   'open-terminal'
      abbr --add chrome 'open-chrome'
      abbr --add vsc    'open-vscode'

      # Flake management
      abbr --add fu      'nixos-flake-update'
      abbr --add fui     'nixos-update-input'
      abbr --add fcheck  'nixos-flake-check'
      abbr --add inputs  'nixos-inputs'
      abbr --add outputs 'nixos-outputs'

      # NixOS rebuild
      abbr --add rebuild  'nixos-switch'
      abbr --add nb       'nixos-build'
      abbr --add nboot    'nixos-boot'
      abbr --add ntest    'nixos-test'
      abbr --add ndry     'nixos-dry'
      abbr --add ndiff    'nixos-diff'
      abbr --add ngen     'nixos-generations'
      abbr --add nroll    'nixos-rollback'
      abbr --add nfmt     'nixos-format'
      abbr --add nlint    'nixos-lint'

      # Full update pipelines
      abbr --add update  'nixos-update'
      abbr --add uall    'nixos-upgrade-all'

      # Garbage collection & store
      abbr --add gc        'nixos-gc'
      abbr --add gcold     'nixos-gc-old'
      abbr --add gcdry     'nixos-gc-dry'
      abbr --add opt       'nixos-optimise'
      abbr --add clean     'nixos-clean'
      abbr --add storesize 'nixos-store-size'

      # Home Manager
      abbr --add hms     'hm-switch'
      abbr --add hmb     'hm-build'
      abbr --add hmnews  'hm-news'
      abbr --add hmpkgs  'hm-packages'
      abbr --add hmgen   'hm-generations'
      abbr --add hmgc    'hm-gc'
      abbr --add hmroll  'hm-rollback'
    '';
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
    zsh-powerlevel10k   # sourced in home/ivali.nix for zsh

    eza                 # modern ls  (ll / ls aliases)
    bat                 # modern cat + MANPAGER
    fd                  # fast find
    ripgrep             # fast grep
    fzf                 # fuzzy finder  (Ctrl-R in both shells)
    zoxide              # smart cd  (z)
    fastfetch           # system info on login

    nixfmt-rfc-style    # nix formatter  (nfmt alias)
    nvd                 # nix closure diff
  ];
}
