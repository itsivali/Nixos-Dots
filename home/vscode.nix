
# ─────────────────────────────────────────────────────────────────────────────
# home/vscode.nix
#
# VS Code configuration managed by Home Manager.
#
# ── Writable settings.json ────────────────────────────────────────────────────
# Home Manager normally writes settings.json as a read-only symlink into the
# Nix store.  To keep Nix-declared settings as the base while still being able
# to save ad-hoc changes from inside VS Code, we use a two-file trick:
#
#   ~/.config/Code/User/settings.json          ← real mutable file (git-tracked)
#   ~/.config/Code/User/settings.nix-base.json ← Nix-owned read-only snapshot
#
# Home Manager writes `settings.nix-base.json` (via home.file, not
# programs.vscode.userSettings).  An activation script merges it with your
# hand-edited `settings.json` on every `home-manager switch`, so Nix values
# always win for any key they declare, while keys you added manually survive.
#
# On first install (no settings.json yet) the file is seeded from the Nix base.
# ─────────────────────────────────────────────────────────────────────────────
{ config, pkgs, lib, ... }:

let
  # ── Language server + tool backends ────────────────────────────────────────
  lspBackends = with pkgs; [
    # Nix
    nil
    nixfmt

    # TypeScript / JavaScript
    nodePackages.typescript-language-server
    nodePackages.vscode-langservers-extracted
    nodePackages.prettier

    # Python
    python3
    python3Packages.python-lsp-server
    python3Packages.black
    python3Packages.isort
    python3Packages.pylint

    # C# / .NET
    dotnet-sdk

    # Flutter / Dart  (dart omitted — flutter ships its own dart binary)
    flutter

    # General
    nodePackages.bash-language-server
    yaml-language-server
  ];

  # ── Settings declared by Nix ────────────────────────────────────────────────
  # These are serialised to ~/.config/Code/User/settings.nix-base.json.
  # On every `home-manager switch` they are deep-merged into the writable
  # settings.json, with Nix values taking precedence.
  nixSettings = {

    # ── GitHub Settings Sync ─────────────────────────────────────────────
    "settingsSync.ignoredSettings"        = [ "*" ];
    "settingsSync.ignoredExtensions"      = [];
    "settingsSync.keybindingsPerPlatform" = false;

    # ── Updater — Nix manages the version ────────────────────────────────
    "update.mode"                      = "none";
    "update.showReleaseNotes"          = false;
    "extensions.autoUpdate"            = false;
    "extensions.autoCheckUpdates"      = false;
    "extensions.ignoreRecommendations" = true;

    # ── Telemetry ─────────────────────────────────────────────────────────
    "telemetry.telemetryLevel"  = "off";
    "redhat.telemetry.enabled"  = false;
    "gitlens.telemetry.enabled" = false;

    # ── Startup ───────────────────────────────────────────────────────────
    "window.restoreWindows"                            = "none";
    "workbench.startupEditor"                          = "none";
    "workbench.tips.enabled"                           = false;
    "workbench.welcomePage.walkthroughs.openOnInstall" = false;

    # ── Rendering ─────────────────────────────────────────────────────────
    "editor.smoothScrolling"              = true;
    "workbench.list.smoothScrolling"      = true;
    "terminal.integrated.smoothScrolling" = true;

    # ── Theme ─────────────────────────────────────────────────────────────
    "workbench.colorTheme" = "One Dark Pro";
    "workbench.iconTheme"  = "material-icon-theme";

    # ── Workbench layout ──────────────────────────────────────────────────
    "workbench.tree.indent"             = 16;
    "workbench.tree.renderIndentGuides" = "always";
    "workbench.editor.enablePreview"    = false;
    "workbench.editor.closeEmptyGroups" = true;
    "workbench.activityBar.location"    = "top";
    "workbench.sideBar.location"        = "left";

    # ── Editor appearance ─────────────────────────────────────────────────
    "editor.fontFamily"                      = "'JetBrainsMono Nerd Font', 'FiraCode Nerd Font', monospace";
    "editor.fontSize"                        = 14;
    "editor.fontLigatures"                   = true;
    "editor.fontWeight"                      = "400";
    "editor.lineHeight"                      = 1.6;
    "editor.minimap.enabled"                 = false;
    "editor.breadcrumbs.enabled"             = false;
    "editor.renderWhitespace"                = "boundary";
    "editor.bracketPairColorization.enabled" = true;
    "editor.guides.bracketPairs"             = "active";
    "editor.cursorBlinking"                  = "smooth";
    "editor.cursorSmoothCaretAnimation"      = "on";
    "editor.stickyScroll.enabled"            = true;

    # ── Editor behaviour ──────────────────────────────────────────────────
    "editor.tabSize"                   = 2;
    "editor.insertSpaces"              = true;
    "editor.detectIndentation"         = true;
    "editor.wordWrap"                  = "off";
    "editor.linkedEditing"             = true;
    "editor.suggest.preview"           = true;
    "editor.inlineSuggest.enabled"     = true;
    "editor.hover.delay"               = 300;
    "editor.hover.sticky"              = true;
    "editor.maxTokenizationLineLength" = 5000;
    "editor.formatOnPaste"             = false;
    "editor.formatOnSave"              = true;
    "editor.formatOnSaveMode"          = "modificationsIfAvailable";

    # ── Autosave ──────────────────────────────────────────────────────────
    "files.autoSave"      = "afterDelay";
    "files.autoSaveDelay" = 1000;

    # ── Files ─────────────────────────────────────────────────────────────
    "files.trimTrailingWhitespace" = true;
    "files.insertFinalNewline"     = true;
    "files.trimFinalNewlines"      = true;
    "files.exclude" = {
      "**/.git"         = true;
      "**/.DS_Store"    = true;
      "**/node_modules" = true;
      "**/__pycache__"  = true;
      "**/.direnv"      = true;
      "**/.dart_tool"   = true;
      "**/result"       = true;
      "**/result-*"     = true;
    };

    # ── File watcher exclusions ───────────────────────────────────────────
    "files.watcherExclude" = {
      "**/.git/objects/**"       = true;
      "**/.git/subtree-cache/**" = true;
      "**/node_modules/**"       = true;
      "**/dist/**"               = true;
      "**/build/**"              = true;
      "**/.dart_tool/**"         = true;
      "**/__pycache__/**"        = true;
      "**/.mypy_cache/**"        = true;
      "**/.direnv/**"            = true;
      "**/result"                = true;
      "**/result-*"              = true;
    };

    # ── Search exclusions ─────────────────────────────────────────────────
    "search.exclude" = {
      "**/node_modules" = true;
      "**/dist"         = true;
      "**/build"        = true;
      "**/.dart_tool"   = true;
      "**/__pycache__"  = true;
      "**/.direnv"      = true;
      "**/result"       = true;
    };
    "search.useRipgrep"     = true;
    "search.followSymlinks" = false;

    # ── Terminal ──────────────────────────────────────────────────────────
    "terminal.integrated.defaultProfile.linux" = "zsh";
    "terminal.integrated.profiles.linux" = {
      zsh  = { path = "/run/current-system/sw/bin/zsh";  icon = "terminal"; };
      fish = { path = "/run/current-system/sw/bin/fish"; icon = "terminal"; };
      bash = { path = "/run/current-system/sw/bin/bash"; icon = "terminal-bash"; };
    };
    "terminal.integrated.fontFamily"               = "'JetBrainsMono Nerd Font'";
    "terminal.integrated.fontSize"                 = 13;
    "terminal.integrated.cursorStyle"              = "line";
    "terminal.integrated.cursorBlinking"           = true;
    "terminal.integrated.scrollback"               = 5000;
    "terminal.integrated.gpuAcceleration"          = "on";
    "terminal.integrated.enablePersistentSessions" = false;

    # ── Git ───────────────────────────────────────────────────────────────
    "git.autofetch"           = true;
    "git.autofetchPeriod"     = 180;
    "git.confirmSync"         = false;
    "git.enableSmartCommit"   = true;
    "git.decorations.enabled" = true;

    # ── GitLens ───────────────────────────────────────────────────────────
    "gitlens.currentLine.enabled"     = false;
    "gitlens.codeLens.enabled"        = false;
    "gitlens.hovers.currentLine.over" = "line";
    "gitlens.statusBar.enabled"       = true;

    # ── LANGUAGE: Nix ─────────────────────────────────────────────────────
    "nix.enableLanguageServer" = true;
    "nix.serverPath"           = "nil";
    "nix.serverSettings"."nil"."formatting"."command" = [ "nixfmt" ];
    "[nix]"."editor.defaultFormatter" = "jnoortheen.nix-ide";
    "[nix]"."editor.tabSize"          = 2;

    # ── LANGUAGE: TypeScript / JavaScript ─────────────────────────────────
    "typescript.updateImportsOnFileMove.enabled"   = "always";
    "typescript.suggest.autoImports"               = true;
    "typescript.inlayHints.parameterNames.enabled" = "literals";
    "javascript.updateImportsOnFileMove.enabled"   = "always";
    "javascript.suggest.autoImports"               = true;
    "[typescript]"."editor.defaultFormatter"       = "esbenp.prettier-vscode";
    "[typescriptreact]"."editor.defaultFormatter"  = "esbenp.prettier-vscode";
    "[javascript]"."editor.defaultFormatter"       = "esbenp.prettier-vscode";
    "[javascriptreact]"."editor.defaultFormatter"  = "esbenp.prettier-vscode";
    "[json]"."editor.defaultFormatter"             = "esbenp.prettier-vscode";
    "[jsonc]"."editor.defaultFormatter"            = "esbenp.prettier-vscode";

    "prettier.singleQuote"   = true;
    "prettier.semi"          = true;
    "prettier.trailingComma" = "es5";
    "prettier.printWidth"    = 100;
    "prettier.tabWidth"      = 2;

    "eslint.run"           = "onSave";
    "eslint.format.enable" = false;

    "tailwindCSS.includeLanguages" = { "plaintext" = "html"; };

    # ── LANGUAGE: Python ──────────────────────────────────────────────────
    "python.defaultInterpreterPath"         = "${pkgs.python3}/bin/python";
    "[python]"."editor.defaultFormatter"    = "ms-python.black-formatter";
    "[python]"."editor.formatOnSave"        = true;
    "python.analysis.typeCheckingMode"      = "basic";
    "python.analysis.autoImportCompletions" = true;

    # ── LANGUAGE: C# / .NET ───────────────────────────────────────────────
    "dotnet.defaultSolution"              = "disable";
    "omnisharp.enableEditorConfigSupport" = true;
    "omnisharp.enableRoslynAnalyzers"     = true;
    "[csharp]"."editor.defaultFormatter"  = "ms-dotnettools.csharp";

    # ── LANGUAGE: Dart / Flutter ──────────────────────────────────────────
    "dart.flutterSdkPath"                = "${pkgs.flutter}";
    "dart.sdkPath"                       = "${pkgs.flutter}/bin/cache/dart-sdk";
    "dart.lineLength"                    = 100;
    "dart.previewFlutterUiGuides"        = true;
    "[dart]"."editor.formatOnSave"       = true;
    "[dart]"."editor.selectionHighlight" = false;
    "[dart]"."editor.tabSize"            = 2;

    # ── LANGUAGE: YAML ────────────────────────────────────────────────────
    "[yaml]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
    "[yaml]"."editor.tabSize"          = 2;

    # ── LANGUAGE: Docker ──────────────────────────────────────────────────
    "[dockerfile]"."editor.defaultFormatter" = "ms-azuretools.vscode-docker";

    # ── Error Lens ────────────────────────────────────────────────────────
    "errorLens.enabledDiagnosticLevels" = [ "error" "warning" ];
    "errorLens.delay"                   = 500;
    "errorLens.followCursor"            = "allLinesExceptActive";

    # ── TODO Tree ─────────────────────────────────────────────────────────
    "todo-tree.general.tags" = [ "TODO" "FIXME" "HACK" "NOTE" "BUG" ];
    "todo-tree.highlights.defaultHighlight" = {
      "type"       = "tag";
      "foreground" = "#f8f8f2";
      "background" = "#ff5555";
      "opacity"    = 50;
    };

    # ── Indent Rainbow ────────────────────────────────────────────────────
    "indentRainbow.ignoreErrorsOnLanguages" = [ "python" "dart" ];

    # ── Spell Checker ─────────────────────────────────────────────────────
    "cSpell.language"        = "en";
    "cSpell.enableFiletypes" = [ "nix" "markdown" "plaintext" ];

  }; # end nixSettings

in
{
  # ── LSP backends on PATH ────────────────────────────────────────────────────
  home.packages = lspBackends;

  # ── Wayland-native launcher via ~/.local/bin/code ───────────────────────────
  home.file.".local/bin/code" = {
    executable = true;
    text = ''
      #!/bin/sh
      exec ${pkgs.vscode-fhs}/bin/code \
        --enable-features=UseOzonePlatform,WaylandWindowDecorations \
        --ozone-platform=wayland \
        --disable-gpu-sandbox \
        --enable-gpu-rasterization \
        "$@"
    '';
  };

  # ── Nix base settings snapshot ──────────────────────────────────────────────
  # Written to a READ-ONLY path (not the live settings.json).
  # The activation script below merges this into the writable settings.json.
  home.file.".config/Code/User/settings.nix-base.json" = {
    text = builtins.toJSON nixSettings;
  };

  # ── VS Code ─────────────────────────────────────────────────────────────────
  programs.vscode = {
    enable  = true;
    package = pkgs.vscode-fhs;

    # Keep extensions directory mutable so GitHub Sync can manage extensions.
    mutableExtensionsDir = true;

    profiles.default = {

      # ── Extensions (Nix-managed) ────────────────────────────────────────────
      # These are installed/updated by Nix on every rebuild.
      # Additional extensions (e.g. GitHub Copilot, language-specific ones) can
      # still be installed via the marketplace — mutableExtensionsDir = true
      # prevents Nix from wiping them on rebuild.
      extensions = with pkgs.vscode-extensions; [
        # ── Themes ────────────────────────────────────────────────────────────
        zhuangtongfa.material-theme          # One Dark Pro
        pkief.material-icon-theme            # Material Icon Theme

        # ── Nix ───────────────────────────────────────────────────────────────
        jnoortheen.nix-ide                   # Nix language support + nil integration

        # ── TypeScript / JavaScript ───────────────────────────────────────────
        esbenp.prettier-vscode               # Prettier formatter
        dbaeumer.vscode-eslint               # ESLint integration
        bradlc.vscode-tailwindcss            # Tailwind CSS IntelliSense

        # ── Python ────────────────────────────────────────────────────────────
        ms-python.python                     # Python language support
        ms-python.black-formatter            # Black formatter

        # ── Git & collaboration ────────────────────────────────────────────────
        eamodio.gitlens                      # Git supercharged
        mhutchie.git-graph                   # Git graph visualiser

        # ── Productivity ──────────────────────────────────────────────────────
        usernamehw.errorlens                 # Inline error/warning display
        gruntfuggly.todo-tree                # TODO/FIXME tree view
        oderwat.indent-rainbow               # Indent guides colourised
        streetsidesoftware.code-spell-checker # Spell checker

        # ── Remote / containers ───────────────────────────────────────────────
        ms-azuretools.vscode-docker          # Docker support

        # ── YAML ──────────────────────────────────────────────────────────────
        redhat.vscode-yaml                   # YAML language support
      ];

      # ── Settings ────────────────────────────────────────────────────────────
      # Intentionally left EMPTY here.
      # Settings are managed via the activation script below (writable
      # settings.json strategy).  Putting values here would cause Home Manager
      # to write a read-only symlink and fight with the activation script.
      userSettings = {};

      # ── Keybindings ───────────────────────────────────────────────────────
      keybindings = [
        { key = "ctrl+`";         command = "workbench.action.terminal.toggleTerminal"; }
        { key = "ctrl+shift+`";   command = "workbench.action.terminal.new"; }
        { key = "ctrl+p";         command = "workbench.action.quickOpen"; }
        { key = "ctrl+shift+p";   command = "workbench.action.showCommands"; }
        { key = "ctrl+shift+i";   command = "editor.action.formatDocument"; }
        { key = "f8";             command = "editor.action.marker.nextInFiles"; }
        { key = "shift+f8";       command = "editor.action.marker.prevInFiles"; }
        { key = "f2";             command = "editor.action.rename"; }
        { key = "ctrl+.";         command = "editor.action.quickFix";
          when = "editorHasCodeActionsProvider && editorTextFocus && !editorReadonly"; }
        { key = "f12";            command = "editor.action.revealDefinition"; }
        { key = "alt+left";       command = "workbench.action.navigateBack"; }
        { key = "alt+right";      command = "workbench.action.navigateForward"; }
        { key = "ctrl+b";         command = "workbench.action.toggleSidebarVisibility"; }
        { key = "ctrl+alt+right"; command = "workbench.action.moveEditorToNextGroup"; }
        { key = "ctrl+alt+left";  command = "workbench.action.moveEditorToPreviousGroup"; }
        { key = "ctrl+d";         command = "editor.action.copyLinesDownAction";
          when = "editorTextFocus && !editorReadonly"; }
        { key = "ctrl+shift+k";   command = "editor.action.deleteLines";
          when = "editorTextFocus && !editorReadonly"; }
        { key = "ctrl+alt+down";  command = "editor.action.insertCursorBelow";
          when = "editorTextFocus"; }
        { key = "ctrl+alt+up";    command = "editor.action.insertCursorAbove";
          when = "editorTextFocus"; }
        { key = "ctrl+f5";        command = "flutter.hotReload"; }
        { key = "ctrl+shift+f5";  command = "flutter.hotRestart"; }
        { key = "ctrl+shift+x";   command = "workbench.view.extensions"; }
        { key = "ctrl+k ctrl+t";  command = "workbench.action.selectTheme"; }
      ];

    }; # end profiles.default
  }; # end programs.vscode

  # ── Writable settings.json activation script ────────────────────────────────
  #
  # Why: Home Manager writes settings.json as a read-only Nix store symlink.
  # This script replaces it with a real mutable file so VS Code (and you) can
  # write to it while still keeping the Nix-declared settings as the base.
  #
  # How it works on every `home-manager switch`:
  #   1. Read the Nix base (settings.nix-base.json) — the source of truth for
  #      Nix-owned keys.
  #   2. If a mutable settings.json already exists, deep-merge it with the base
  #      (base wins for any conflicting key, user-added keys are preserved).
  #   3. Write the merged result as a real file (not a symlink).
  #
  # Result: you can freely edit settings.json inside VS Code and your changes
  # survive rebuilds, except for keys that Nix explicitly declares (which are
  # always restored to their Nix values).
  #
  home.activation.writableVscodeSettings =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      set -euo pipefail

      BASE="$HOME/.config/Code/User/settings.nix-base.json"
      LIVE="$HOME/.config/Code/User/settings.json"

      # Ensure the directory exists
      mkdir -p "$HOME/.config/Code/User"

      # If Home Manager wrote a symlink here (from a previous approach), remove it
      if [ -L "$LIVE" ]; then
        echo "vscode-settings: replacing read-only symlink with mutable file"
        rm "$LIVE"
      fi

      if [ ! -f "$LIVE" ]; then
        # First run: seed from Nix base
        echo "vscode-settings: seeding settings.json from Nix base"
        ${pkgs.jq}/bin/jq '.' "$BASE" > "$LIVE"
      else
        # Subsequent runs: merge (base keys win over existing user keys)
        echo "vscode-settings: merging Nix base into existing settings.json"
        ${pkgs.jq}/bin/jq \
          --slurpfile base "$BASE" \
          '. as $user | $base[0] * $user * $base[0]' \
          "$LIVE" > "$LIVE.tmp" && mv "$LIVE.tmp" "$LIVE"
      fi
    '';
}
