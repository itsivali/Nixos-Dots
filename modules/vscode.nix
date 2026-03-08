# home/vscode.nix
# ─────────────────────────────────────────────────────────────────────────────
# VS Code — declarative, performance-tuned, GitHub Sync aware
#
# Design decisions
#   extensions    Declared here in Nix so every rebuild is reproducible.
#                 GitHub Settings Sync supplements them (adds anything you
#                 install at runtime) but is told to IGNORE settings and
#                 keybindings, which Nix manages exclusively.
#
#   autosave      "afterDelay" 1 000 ms — saves 1 second after you stop
#                 typing.  Fast enough to feel instant, slow enough that
#                 half-typed lines don't trigger LSP errors mid-word.
#
#   theme         One Dark Pro (zhuangtongfa.material-theme).  Change
#                 "workbench.colorTheme" to any installed theme name.
#
#   view ext      Run in terminal:  code --list-extensions
#   view theme    Ctrl+K Ctrl+T   (or Preferences → Color Theme)
#
# Import in home/ivali.nix:
#   imports = [ ./vscode.nix ];
# ─────────────────────────────────────────────────────────────────────────────
{ config, pkgs, lib, ... }:

let
  # ── Language server + tool backends ────────────────────────────────────────
  # Installed into the FHS env so extensions find them without prompting.
  lspBackends = with pkgs; [
    # Nix
    nil                                          # Nix LSP
    nixfmt                                       # Nix formatter

    # TypeScript / JavaScript
    nodePackages.typescript-language-server      # TS/JS LSP
    nodePackages.vscode-langservers-extracted    # HTML · CSS · JSON · ESLint LSPs
    nodePackages.prettier                        # formatter

    # Python
    python3                                      # runtime
    python3Packages.python-lsp-server            # pylsp
    python3Packages.black                        # formatter
    python3Packages.isort                        # import sorter
    python3Packages.pylint                       # linter

    # C# / .NET
    dotnet-sdk                                   # SDK + runtime

    # Flutter / Dart
    flutter                                      # SDK (bundles Dart)
    dart                                         # explicit for PATH

    # General
    nodePackages.bash-language-server            # shell LSP
    yaml-language-server                         # YAML LSP
  ];

  # ── VS Code package — FHS wrapper + LSP backends injected ─────────────────
  # vscode-fhs creates a FHS-compatible env so extensions with native binaries
  # (Pylance, Copilot, etc.) work without manual patching on NixOS.
  vscodePkg = pkgs.vscode-fhs.override {
    extraLibraries = lspBackends;
  };

  # ── Wayland-native launcher ─────────────────────────────────────────────────
  # Replaces the plain `code` binary with one that passes Ozone flags so VS Code
  # runs on the Wayland compositor directly (no XWayland translation layer).
  # This is the single biggest responsiveness improvement on a GNOME/Wayland system.
  vscodeWrapper = pkgs.writeShellScriptBin "code" ''
    exec ${vscodePkg}/bin/code \
      --enable-features=UseOzonePlatform,WaylandWindowDecorations \
      --ozone-platform=wayland \
      --disable-gpu-sandbox \
      --enable-gpu-rasterization \
      "$@"
  '';

  # ── Marketplace extensions not yet in nixpkgs ──────────────────────────────
  # sha256 hashes are pinned; update them with:
  #   nix-prefetch-url --unpack \
  #     https://marketplace.visualstudio.com/_apis/public/gallery/publishers/<pub>/vsextensions/<name>/<ver>/vspackage
  marketplaceExtensions = map pkgs.vscode-utils.extensionFromVscodeMarketplace [
    {
      name      = "vscode-typescript-next";
      publisher = "ms-vscode";
      version   = "5.8.20250507";
      sha256    = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    }
    {
      name      = "vscode-todo-highlight";
      publisher = "wayou";
      version   = "1.0.5";
      sha256    = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
    }
    {
      name      = "LiveServer";
      publisher = "ritwickdey";
      version   = "5.7.9";
      sha256    = "sha256-CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=";
    }
  ];

in
{
  # ── LSP backends + Wayland wrapper on PATH ─────────────────────────────────
  home.packages = lspBackends ++ [ vscodeWrapper ];

  # ── VS Code ─────────────────────────────────────────────────────────────────
  programs.vscode = {
    enable  = true;
    package = vscodePkg;

    profiles.default = {

      # ════════════════════════════════════════════════════════════════════════
      # EXTENSIONS
      # All extensions are installed by Nix at rebuild time — no marketplace
      # prompts, no version drift between machines.
      #
      # To view what's installed:   code --list-extensions
      # To see in the UI:           Ctrl+Shift+X  (Extensions panel)
      # To change theme:            Ctrl+K Ctrl+T
      # ════════════════════════════════════════════════════════════════════════
      extensions = (with pkgs.vscode-extensions; [

        # ── Nix ──────────────────────────────────────────────────────────────
        jnoortheen.nix-ide                       # syntax, LSP, formatter

        # ── TypeScript / JavaScript / React ──────────────────────────────────
        dbaeumer.vscode-eslint                   # linting
        esbenp.prettier-vscode                   # formatting
        formulahendry.auto-rename-tag            # paired HTML tag rename
        bradlc.vscode-tailwindcss                # Tailwind IntelliSense

        # ── Python ───────────────────────────────────────────────────────────
        ms-python.python                         # core extension
        ms-python.vscode-pylance                 # fast type-checked IntelliSense
        ms-python.black-formatter                # Black formatter integration

        # ── C# / .NET ────────────────────────────────────────────────────────
        ms-dotnettools.csharp                    # OmniSharp / Roslyn
        ms-dotnettools.vscode-dotnet-runtime     # runtime installer shim

        # ── Flutter / Dart ────────────────────────────────────────────────────
        dart-code.flutter                        # Flutter DevTools, hot reload
        dart-code.dart-code                      # Dart LSP, debugger

        # ── Docker / Remote ───────────────────────────────────────────────────
        ms-azuretools.vscode-docker              # Dockerfile, Compose
        ms-vscode-remote.remote-ssh              # SSH workspaces
        ms-vscode-remote.remote-ssh-edit         # edit SSH config
        ms-vscode-remote.remote-containers       # Dev Containers

        # ── Git ───────────────────────────────────────────────────────────────
        eamodio.gitlens                          # git blame, history, graph
        github.vscode-pull-request-github        # PR review inline
        github.vscode-github-actions             # Actions workflow YAML

        # ── AI ────────────────────────────────────────────────────────────────
        github.copilot                           # inline completions
        github.copilot-chat                      # chat sidebar

        # ── Languages / formats ───────────────────────────────────────────────
        redhat.vscode-yaml                       # YAML schema validation
        rust-lang.rust-analyzer                  # Rust LSP
        golang.go                                # Go LSP + tools
        streetsidesoftware.code-spell-checker    # spell check in code + comments

        # ── Theme / UI ────────────────────────────────────────────────────────
        # Change "workbench.colorTheme" in userSettings below to switch.
        zhuangtongfa.material-theme              # One Dark Pro (default active)
        dracula-theme.theme-dracula              # Dracula (available, not active)
        pkief.material-icon-theme                # file icons

        # ── Productivity ──────────────────────────────────────────────────────
        usernamehw.errorlens                     # inline error/warning text
        gruntfuggly.todo-tree                    # TODO/FIXME tree panel
        christian-kohler.path-intellisense       # path autocomplete in strings
        oderwat.indent-rainbow                   # coloured indent guides

      ])
      # Marketplace extensions pinned above — comment these out until you
      # update the sha256 hashes with real values from nix-prefetch-url.
      # ++ marketplaceExtensions
      ;

      # ════════════════════════════════════════════════════════════════════════
      # SETTINGS
      # ════════════════════════════════════════════════════════════════════════
      userSettings = {

        # ── GitHub Settings Sync ─────────────────────────────────────────────
        # Sign in with GitHub (Accounts icon, bottom-left) to activate sync.
        # Sync is configured to handle ONLY extensions you install at runtime —
        # settings, keybindings, and snippets stay under Nix control so they
        # never get overwritten by a sync pull.
        "settingsSync.ignoredSettings"    = [ "*" ];   # Nix owns all settings
        "settingsSync.ignoredExtensions"  = [];         # sync CAN add new extensions
        "settingsSync.keybindingsPerPlatform" = false;
        # Snippets and UI state are fine to sync — they're not declared in Nix
        "sync.gist"                       = "";         # optional: set your gist ID

        # ── AUTOSAVE ─────────────────────────────────────────────────────────
        # afterDelay: saves 1 second after you stop typing.
        # Feels instant in practice; avoids triggering LSP on every keystroke.
        "files.autoSave"                  = "afterDelay";
        "files.autoSaveDelay"             = 1000;
        # Format on every explicit Ctrl+S (autosave does NOT trigger formatOnSave)
        "editor.formatOnSave"             = true;
        # Don't format if you haven't edited (avoids surprise changes on open)
        "editor.formatOnSaveMode"         = "modificationsIfAvailable";

        # ── Updater — Nix manages the version ────────────────────────────────
        "update.mode"                     = "none";
        "update.showReleaseNotes"         = false;
        "extensions.autoUpdate"           = false;
        "extensions.autoCheckUpdates"     = false;
        "extensions.ignoreRecommendations" = true;

        # ── Telemetry ─────────────────────────────────────────────────────────
        "telemetry.telemetryLevel"        = "off";
        "redhat.telemetry.enabled"        = false;
        "gitlens.telemetry.enabled"       = false;

        # ── Startup — keep cold-start fast ───────────────────────────────────
        "window.restoreWindows"           = "none";
        "workbench.startupEditor"         = "none";
        "workbench.tips.enabled"          = false;
        "workbench.welcomePage.walkthroughs.openOnInstall" = false;

        # ── Rendering — GPU path on Wayland ──────────────────────────────────
        "editor.experimentalGpuAcceleration"    = "on";
        "editor.smoothScrolling"                = true;
        "workbench.list.smoothScrolling"        = true;
        "terminal.integrated.smoothScrolling"   = true;

        # ── Theme — change this string to switch between installed themes ─────
        # Available:  "One Dark Pro"  |  "Dracula"  |  "Default Dark Modern"
        # Press Ctrl+K Ctrl+T to pick interactively.
        "workbench.colorTheme"            = "One Dark Pro";
        "workbench.iconTheme"             = "material-icon-theme";
        "workbench.productIconTheme"      = "material-product-icons";

        # ── Workbench layout ──────────────────────────────────────────────────
        "workbench.tree.indent"           = 16;
        "workbench.tree.renderIndentGuides" = "always";
        "workbench.editor.enablePreview"  = false;  # single-click opens permanently
        "workbench.editor.closeEmptyGroups" = true;
        "workbench.activityBar.location"  = "top";  # saves horizontal space
        "workbench.sideBar.location"      = "left";

        # ── Editor appearance ─────────────────────────────────────────────────
        "editor.fontFamily"               = "'JetBrainsMono Nerd Font', 'FiraCode Nerd Font', monospace";
        "editor.fontSize"                 = 14;
        "editor.fontLigatures"            = true;
        "editor.fontWeight"               = "400";
        "editor.lineHeight"               = 1.6;
        "editor.minimap.enabled"          = false;
        "editor.breadcrumbs.enabled"      = false;
        "editor.renderWhitespace"         = "boundary";
        "editor.bracketPairColorization.enabled" = true;
        "editor.guides.bracketPairs"      = "active";
        "editor.cursorBlinking"           = "smooth";
        "editor.cursorSmoothCaretAnimation" = "on";
        "editor.stickyScroll.enabled"     = true;

        # ── Editor behaviour ──────────────────────────────────────────────────
        "editor.tabSize"                  = 2;
        "editor.insertSpaces"             = true;
        "editor.detectIndentation"        = true;
        "editor.wordWrap"                 = "off";
        "editor.linkedEditing"            = true;    # auto-rename paired HTML tags
        "editor.suggest.preview"          = true;
        "editor.inlineSuggest.enabled"    = true;    # Copilot ghost text
        "editor.hover.delay"              = 300;
        "editor.hover.sticky"             = true;
        "editor.maxTokenizationLineLength" = 5000;   # avoid hanging on minified files
        "editor.formatOnPaste"            = false;   # can be slow on large pastes

        # ── Files ─────────────────────────────────────────────────────────────
        "files.trimTrailingWhitespace"    = true;
        "files.insertFinalNewline"        = true;
        "files.trimFinalNewlines"         = true;
        "files.exclude" = {
          "**/.git"           = true;
          "**/.DS_Store"      = true;
          "**/node_modules"   = true;
          "**/__pycache__"    = true;
          "**/.direnv"        = true;
          "**/.dart_tool"     = true;
          "**/result"         = true;
          "**/result-*"       = true;
        };

        # ── File watcher exclusions — biggest idle-CPU saving ─────────────────
        # Without these, inotify watches are created for node_modules (100k+
        # files), .dart_tool, __pycache__, etc. — causing constant wakeups.
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
          "**/node_modules"  = true;
          "**/dist"          = true;
          "**/build"         = true;
          "**/.dart_tool"    = true;
          "**/__pycache__"   = true;
          "**/.direnv"       = true;
          "**/result"        = true;
        };
        "search.useRipgrep"               = true;
        "search.followSymlinks"           = false;

        # ── Terminal ──────────────────────────────────────────────────────────
        "terminal.integrated.defaultProfile.linux" = "fish";
        "terminal.integrated.profiles.linux" = {
          fish = { path = "/run/current-system/sw/bin/fish"; };
          zsh  = { path = "/run/current-system/sw/bin/zsh";  icon = "terminal"; };
          bash = { path = "/run/current-system/sw/bin/bash"; icon = "terminal-bash"; };
        };
        "terminal.integrated.fontFamily"          = "'JetBrainsMono Nerd Font'";
        "terminal.integrated.fontSize"            = 13;
        "terminal.integrated.cursorStyle"         = "line";
        "terminal.integrated.cursorBlinking"      = true;
        "terminal.integrated.scrollback"          = 5000;
        "terminal.integrated.gpuAcceleration"     = "on";
        "terminal.integrated.enablePersistentSessions" = false;

        # ── Git ───────────────────────────────────────────────────────────────
        "git.autofetch"                   = true;
        "git.autofetchPeriod"             = 180;
        "git.confirmSync"                 = false;
        "git.enableSmartCommit"           = true;
        "git.decorations.enabled"         = true;

        # GitLens — trim expensive features that run on every cursor move
        "gitlens.currentLine.enabled"     = false;  # per-line blame (costs CPU)
        "gitlens.codeLens.enabled"        = false;  # per-symbol commit count
        "gitlens.hovers.currentLine.over" = "line";
        "gitlens.statusBar.enabled"       = true;

        # ── LANGUAGE: Nix ─────────────────────────────────────────────────────
        "nix.enableLanguageServer"        = true;
        "nix.serverPath"                  = "nil";
        "nix.serverSettings"."nil"."formatting"."command" = [ "nixfmt" ];
        "[nix]"."editor.defaultFormatter" = "jnoortheen.nix-ide";
        "[nix]"."editor.tabSize"          = 2;

        # ── LANGUAGE: TypeScript / JavaScript ─────────────────────────────────
        "typescript.updateImportsOnFileMove.enabled"    = "always";
        "typescript.suggest.autoImports"                = true;
        "typescript.inlayHints.parameterNames.enabled"  = "literals";
        "javascript.updateImportsOnFileMove.enabled"    = "always";
        "javascript.suggest.autoImports"                = true;
        "[typescript]"."editor.defaultFormatter"        = "esbenp.prettier-vscode";
        "[typescriptreact]"."editor.defaultFormatter"   = "esbenp.prettier-vscode";
        "[javascript]"."editor.defaultFormatter"        = "esbenp.prettier-vscode";
        "[javascriptreact]"."editor.defaultFormatter"   = "esbenp.prettier-vscode";
        "[json]"."editor.defaultFormatter"              = "esbenp.prettier-vscode";
        "[jsonc]"."editor.defaultFormatter"             = "esbenp.prettier-vscode";

        # Prettier
        "prettier.singleQuote"            = true;
        "prettier.semi"                   = true;
        "prettier.trailingComma"          = "es5";
        "prettier.printWidth"             = 100;
        "prettier.tabWidth"               = 2;

        # ESLint — lint on save only (onType causes constant background work)
        "eslint.run"                      = "onSave";
        "eslint.format.enable"            = false;   # Prettier formats; ESLint lints

        # Tailwind
        "tailwindCSS.includeLanguages"    = { "plaintext" = "html"; };

        # ── LANGUAGE: Python ──────────────────────────────────────────────────
        "python.defaultInterpreterPath"             = "${pkgs.python3}/bin/python";
        "[python]"."editor.defaultFormatter"        = "ms-python.black-formatter";
        "[python]"."editor.formatOnSave"            = true;
        "python.analysis.typeCheckingMode"          = "basic";
        "python.analysis.autoImportCompletions"     = true;

        # ── LANGUAGE: C# / .NET ───────────────────────────────────────────────
        "dotnet.defaultSolution"                    = "disable";
        "omnisharp.enableEditorConfigSupport"       = true;
        "omnisharp.enableRoslynAnalyzers"           = true;
        "[csharp]"."editor.defaultFormatter"        = "ms-dotnettools.csharp";

        # ── LANGUAGE: Dart / Flutter ──────────────────────────────────────────
        "dart.flutterSdkPath"                       = "${pkgs.flutter}";
        "dart.sdkPath"                              = "${pkgs.dart}";
        "dart.lineLength"                           = 100;
        "dart.previewFlutterUiGuides"               = true;
        "[dart]"."editor.formatOnSave"              = true;
        "[dart]"."editor.selectionHighlight"        = false;
        "[dart]"."editor.tabSize"                   = 2;

        # ── LANGUAGE: YAML ────────────────────────────────────────────────────
        "[yaml]"."editor.defaultFormatter"          = "esbenp.prettier-vscode";
        "[yaml]"."editor.tabSize"                   = 2;

        # ── LANGUAGE: Docker ──────────────────────────────────────────────────
        "[dockerfile]"."editor.defaultFormatter"    = "ms-azuretools.vscode-docker";

        # ── EXTENSION: Error Lens ─────────────────────────────────────────────
        "errorLens.enabledDiagnosticLevels"         = [ "error" "warning" ];
        "errorLens.delay"                           = 500;
        "errorLens.followCursor"                    = "allLinesExceptActive";

        # ── EXTENSION: TODO Tree ──────────────────────────────────────────────
        "todo-tree.general.tags"                    = [ "TODO" "FIXME" "HACK" "NOTE" "BUG" ];
        "todo-tree.highlights.defaultHighlight" = {
          "type"       = "tag";
          "foreground" = "#f8f8f2";
          "background" = "#ff5555";
          "opacity"    = 50;
        };

        # ── EXTENSION: Indent Rainbow ─────────────────────────────────────────
        "indentRainbow.ignoreErrorsOnLanguages" = [ "python" "dart" ];

        # ── EXTENSION: Spell Checker ──────────────────────────────────────────
        "cSpell.language"                           = "en";
        "cSpell.enableFiletypes"                    = [ "nix" "markdown" "plaintext" ];

      }; # end userSettings

      # ════════════════════════════════════════════════════════════════════════
      # KEYBINDINGS
      # ════════════════════════════════════════════════════════════════════════
      keybindings = [
        # Terminal
        { key = "ctrl+`";         command = "workbench.action.terminal.toggleTerminal"; }
        { key = "ctrl+shift+`";   command = "workbench.action.terminal.new"; }

        # Command palette / file finder
        { key = "ctrl+p";         command = "workbench.action.quickOpen"; }
        { key = "ctrl+shift+p";   command = "workbench.action.showCommands"; }

        # Format document (explicit save — autosave also triggers formatOnSave)
        { key = "ctrl+shift+i";   command = "editor.action.formatDocument"; }

        # Problems navigation (Error Lens shows inline; F8 jumps between them)
        { key = "f8";             command = "editor.action.marker.nextInFiles"; }
        { key = "shift+f8";       command = "editor.action.marker.prevInFiles"; }

        # Symbol rename
        { key = "f2";             command = "editor.action.rename"; }

        # Quick fix / code action
        { key = "ctrl+.";         command = "editor.action.quickFix";
          when = "editorHasCodeActionsProvider && editorTextFocus && !editorReadonly"; }

        # Go to definition / navigate back-forward
        { key = "f12";            command = "editor.action.revealDefinition"; }
        { key = "alt+left";       command = "workbench.action.navigateBack"; }
        { key = "alt+right";      command = "workbench.action.navigateForward"; }

        # Sidebar toggle
        { key = "ctrl+b";         command = "workbench.action.toggleSidebarVisibility"; }

        # Move tab to split group
        { key = "ctrl+alt+right"; command = "workbench.action.moveEditorToNextGroup"; }
        { key = "ctrl+alt+left";  command = "workbench.action.moveEditorToPreviousGroup"; }

        # Duplicate / delete line  (IntelliJ muscle memory)
        { key = "ctrl+d";         command = "editor.action.copyLinesDownAction";
          when = "editorTextFocus && !editorReadonly"; }
        { key = "ctrl+shift+k";   command = "editor.action.deleteLines";
          when = "editorTextFocus && !editorReadonly"; }

        # Multi-cursor
        { key = "ctrl+alt+down";  command = "editor.action.insertCursorBelow";
          when = "editorTextFocus"; }
        { key = "ctrl+alt+up";    command = "editor.action.insertCursorAbove";
          when = "editorTextFocus"; }

        # Flutter hot reload / restart
        { key = "ctrl+f5";        command = "flutter.hotReload"; }
        { key = "ctrl+shift+f5";  command = "flutter.hotRestart"; }

        # Extensions panel  (Ctrl+Shift+X — see all installed extensions)
        { key = "ctrl+shift+x";   command = "workbench.view.extensions"; }

        # Theme picker  (same as Ctrl+K Ctrl+T — pick colour theme interactively)
        { key = "ctrl+k ctrl+t";  command = "workbench.action.selectTheme"; }
      ];

    }; # end profiles.default
  }; # end programs.vscode
}
