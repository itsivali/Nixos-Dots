# Terminal Configuration Module
# Beautiful, productive terminal setup with system info display
{ config, pkgs, lib, ... }:

{
  # ===========================
  # Shell Configuration
  # ===========================

  programs.bash = {
    completion.enable = true;
    enableLsColors = true;
  };

  # Keep zsh enabled at system level, but DO NOT run fastfetch here
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    autosuggestions.enable = true;
    # No interactiveShellInit fastfetch here (Home Manager will handle it)
  };

  # ===========================
  # Environment Variables
  # ===========================

  environment.variables = {
    # Editor
    EDITOR = "vim";
    VISUAL = "code";

    # Terminal Colors
    TERM = "xterm-256color";
    COLORTERM = "truecolor";

    # Less with colors
    LESS = "-R";

    # FZF
    FZF_DEFAULT_OPTS = "--height 40% --layout=reverse --border --inline-info";
    FZF_DEFAULT_COMMAND = "fd --type f --hidden --follow --exclude .git";

    # Bat (better cat)
    BAT_THEME = "TwoDark";

    # Manpager with colors
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
  };

  # ===========================
  # Terminal Tools
  # ===========================

  programs.fzf = {
    keybindings = true;
    fuzzyCompletion = true;
  };

  # Direnv for automatic environment loading
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # ===========================
  # Fastfetch Configuration
  # ===========================

  # Create fastfetch config in /etc
  environment.etc."fastfetch/config.jsonc".text = builtins.toJSON {
    "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";
    logo = {
      type = "auto";
      padding = {
        top = 1;
        left = 2;
      };
    };
    display = {
      separator = " → ";
      color = {
        keys = "cyan";
        title = "blue";
      };
    };
    modules = [
      { type = "title"; format = "{user-name}@{host-name}"; }
      "separator"
      { type = "os"; key = " OS"; }
      { type = "host"; key = "󰌢 Host"; }
      { type = "kernel"; key = " Kernel"; }
      { type = "uptime"; key = " Uptime"; }
      { type = "packages"; key = "󰏖 Packages"; }
      { type = "shell"; key = " Shell"; }
      "separator"
      { type = "display"; key = "󰍹 Display"; }
      { type = "de"; key = " DE"; }
      { type = "wm"; key = " WM"; }
      { type = "terminal"; key = " Terminal"; }
      "separator"
      { type = "cpu"; key = "󰻠 CPU"; }
      { type = "gpu"; key = "󰢮 GPU"; }
      { type = "memory"; key = " Memory"; }
      { type = "disk"; key = "󰋊 Disk"; }
      "separator"
      { type = "localip"; key = "󰩟 Local IP"; }
      { type = "battery"; key = " Battery"; }
      "separator"
      { type = "colors"; symbol = "circle"; }
    ];
  };

  # ===========================
  # Default Applications
  # ===========================

  environment.sessionVariables = {
    TERMINAL = "kitty";
  };
}

