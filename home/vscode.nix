
# ─────────────────────────────────────────────────────────────────────────────
{ config, pkgs, lib, ... }:

let
  # ── Language server + tool backends ────────────────────────────────────────
  # Placed on PATH so extensions (Pylance, nil, dart-code…) find binaries
  # without downloading them or prompting the user.
  #
  # Rules that prevent buildEnv collisions:
  #   • dart omitted  — flutter already bundles dart; having both → /bin/dart clash
  lspBackends = with pkgs; [
    # Nix
    nil                                       # nil LSP
    nixfmt                                    # nix formatter

    # TypeScript / JavaScript
    nodePackages.typescript-language-server   # tsserver
    nodePackages.vscode-langservers-extracted # HTML · CSS · JSON · ESLint LSPs
    nodePackages.prettier                     # formatter

    # Python
    python3                                   # runtime
    python3Packages.python-lsp-server         # pylsp
    python3Packages.black                     # formatter
    python3Packages.isort                     # import sorter
    python3Packages.pylint                    # linter

    # C# / .NET
    dotnet-sdk                                # SDK + runtime

    # Flutter / Dart
    # dart intentionally omitted — flutter ships its own dart binary;
    # having both causes a /bin/dart collision in buildEnv.
    flutter                                   # SDK (includes Dart)

    # General
    nodePackages.bash-language-server         # shell LSP
    yaml-language-server                      # YAML LSP
  ];

in
{
  # ── LSP backends on PATH ────────────────────────────────────────────────────
  home.packages = lspBackends;

  # ── Wayland-native launcher via ~/.local/bin/code ───────────────────────────
  # Shadow-wraps the real VS Code binary with Ozone flags so VS Code renders
  # on the Wayland compositor directly — no XWayland translation layer.
  # ~/.local/bin is first on PATH (home.sessionPath in ivali.nix), so this
  # binary wins over /bin/code from the Nix store without any buildEnv clash.
  # programs.vscode.package stays as pkgs.vscode-fhs (a real derivation with
  # .pname + .version) so Home Manager does not error on cfg.package.pname.
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

  # ── VS Code ─────────────────────────────────────────────────────────────────
  programs.vscode = {
    enable  = true;
    # Must be a real derivation with .pname + .version — NOT writeShellScriptBin.
    # Home Manager reads cfg.package.pname internally; a script derivation fails.
    package = pkgs.vscode-fhs;

    # Prevent Home Manager from wiping ~/.vscode/extensions on every rebuild.
    # Without this, GitHub Sync's installed extensions get deleted each switch.
    mutableExtensionsDir = true;

    profiles.default = {

      # Extensions are owned by GitHub Settings Sync — not Nix.
      # After rebuild: Ctrl+Shift+P → "Settings Sync: Turn On" → sign in with GitHub.
      extensions = [];

      # ════════════════════════════════════════════════════════════════════════
      # SETTINGS
      # Nix owns these. settingsSync.ignoredSettings = ["*"] means a sync
      # pull from GitHub will never overwrite what is declared below.
      # ════════════════════════════════════════════════════════════════════════
      userSettings = {

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

        # ── Startup — cold-start as fast as possible ──────────────────────────
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

        # ── Autosave ──────────────────────────────────────────────────────────
        "files.autoSave"          = "afterDelay";
        "files.autoSaveDelay"     = 1000;
        "editor.formatOnSave"     = true;
        "editor.formatOnSaveMode" = "modificationsIfAvailable";

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
        # sdkPath points inside flutter's bundled SDK (pkgs.dart not installed).
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

      }; # end userSettings

      # ════════════════════════════════════════════════════════════════════════
      # KEYBINDINGS
      # ════════════════════════════════════════════════════════════════════════
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
}
