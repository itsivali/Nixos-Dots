# Powerlevel10k config (Home Manager friendly, fast + stable)
# - No wizard prompts (HM makes .zshrc read-only)
# - Minimal segments (snappy prompt render)
# - Safe VCS settings (prevents lag in huge repos)
#
# Requires a Nerd Font in your terminal (e.g. MesloLGS NF / JetBrainsMono Nerd Font).

# Temporarily change options.
'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob

  # Allows "source ~/.config/zsh/p10k.zsh" without restarting zsh.
  unset -m '(POWERLEVEL9K_*|DEFAULT_USER)~POWERLEVEL9K_GITSTATUS_DIR'

  # Zsh >= 5.1 is required.
  [[ $ZSH_VERSION == (5.<1->*|<6->.*) ]] || return

  # Stop Powerlevel10k from launching its wizard (HM .zshrc is read-only).
  typeset -g POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true

  # Instant prompt (you already source the instant prompt file in .zshrc).
  # Keep it quiet so you don't see warnings.
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

  # ----------------------------
  # Prompt elements (FAST)
  # ----------------------------
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    os_icon
    dir
    vcs
    newline
    prompt_char
  )

  # Keep right prompt minimal (status only on error + time).
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
    status
    time
  )

  # Character set (you used nerdfont-v3).
  typeset -g POWERLEVEL9K_MODE=nerdfont-v3
  typeset -g POWERLEVEL9K_ICON_PADDING=none
  typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=true

  # Multiline ornaments (subtle, still fast).
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX='%244F╭─'
  typeset -g POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_PREFIX='%244F├─'
  typeset -g POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX='%244F╰─'
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_SUFFIX='%244F─╮'
  typeset -g POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_SUFFIX='%244F─┤'
  typeset -g POWERLEVEL9K_MULTILINE_LAST_PROMPT_SUFFIX='%244F─╯'
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_CHAR=' '
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_FOREGROUND=244

  # Separators.
  typeset -g POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR='\uE0B1'
  typeset -g POWERLEVEL9K_RIGHT_SUBSEGMENT_SEPARATOR='\uE0B3'
  typeset -g POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR='\uE0B0'
  typeset -g POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR='\uE0B2'

  # ----------------------------
  # dir (FAST + readable)
  # ----------------------------
  typeset -g POWERLEVEL9K_DIR_HYPERLINK=false
  typeset -g POWERLEVEL9K_DIR_SHOW_WRITABLE=v3
  typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=1
  typeset -g POWERLEVEL9K_DIR_MAX_LENGTH=70
  typeset -g POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS=40
  typeset -g POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS_PCT=50

  # ----------------------------
  # vcs (FAST + safe in big repos)
  # ----------------------------
  typeset -g POWERLEVEL9K_VCS_BACKENDS=(git)
  typeset -g POWERLEVEL9K_VCS_BRANCH_ICON='\uF126 '
  typeset -g POWERLEVEL9K_VCS_PREFIX='on '
  # Prevent slowdowns in huge repos by not scanning dirty state past this many index entries.
  # If you work in giant repos, lower this further (e.g. 2000).
  typeset -g POWERLEVEL9K_VCS_MAX_INDEX_SIZE_DIRTY=5000
  # Keep gitstatus enabled (fast daemon) but don't show it in $HOME itself.
  typeset -g POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN='~'

  # ----------------------------
  # status (only show when non-zero)
  # ----------------------------
  typeset -g POWERLEVEL9K_STATUS_EXTENDED_STATES=true
  typeset -g POWERLEVEL9K_STATUS_OK=false
  typeset -g POWERLEVEL9K_STATUS_OK_PIPE=false
  typeset -g POWERLEVEL9K_STATUS_ERROR=true
  typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE=true
  typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL=true
  typeset -g POWERLEVEL9K_STATUS_VERBOSE_SIGNAME=false

  # ----------------------------
  # time (simple 24h)
  # ----------------------------
  typeset -g POWERLEVEL9K_TIME_FORMAT='%D{%H:%M:%S}'

  # ----------------------------
  # prompt char
  # ----------------------------
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VIINS='❯'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VICMD='❮'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_VIINS='❯'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_VICMD='❮'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_FOREGROUND=2
  typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_FOREGROUND=1

  # A little polish.
  typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND=6
  typeset -g POWERLEVEL9K_DIR_FOREGROUND=7
  typeset -g POWERLEVEL9K_VCS_FOREGROUND=0
  typeset -g POWERLEVEL9K_VCS_CLEAN_BACKGROUND=2
  typeset -g POWERLEVEL9K_VCS_MODIFIED_BACKGROUND=3
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND=2
  typeset -g POWERLEVEL9K_VCS_CONFLICTED_BACKGROUND=3
  typeset -g POWERLEVEL9K_VCS_LOADING_BACKGROUND=8
}

# Restore options.
(( ${#p10k_config_opts} )) && 'builtin' 'setopt' ${p10k_config_opts[@]}
'builtin' 'unset' 'p10k_config_opts'
