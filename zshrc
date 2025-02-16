# Personal ZSH configuration file.
zmodload zsh/zprof



fpath=($(for f in $(echo $fpath[@]); do echo $f; done | sort | uniq))

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

if [[ -f "$HOME/.zshrc.local" ]]; then
  source "$HOME/.zshrc.local"
fi

if [[ -f "$HOME/.zshrc.secrets" ]]; then
  source "$HOME/.zshrc.secrets"
fi

# Shell GPT
export OPENAI_BASE_URL=https://api.openai.com/v1

# If you come from bash you might have to change your $PATH.
export PATH=$HOME/bin:$HOME/.local/bin:$PATH
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
export PATH="$PATH:$HOME/.local/go_workspace/bin/"

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k" # set by `omz`

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="false"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# # Animation des points d'attente de complétion
COMPLETION_WAITING_DOTS_CUSTOM="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
HIST_STAMPS="dd/mm/yyyy"

ZSH_WEB_SEARCH_ENGINES=(
	searng 'https://searxng.containers.obeone.org/search?q='
)

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins+=(git kubectl command-not-found helm copyfile web-search git-flow python pip colorize git-commit zsh-autosuggestions zsh-navigation-tools sudo brew colored-man-pages dirhistory grc gnu-utils zsh-completions fast-syntax-highlighting fzf)


if [[ "$OSTYPE" == darwin* || -e "$DBUS_SESSION_BUS_ADDRESS" ]]; then
	plugins+=(bgnotify)
fi

if [[ -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]]; then
  plugins+=(zsh-autosuggestions)
fi

export FPATH=$HOME/.zsh_completions:$FPATH


source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='code-as-editor'
fi


# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"


# CONTAINERS
export COSIGN_EXPERIMENTAL=1
export HELM_EXPERIMENTAL_OCI=1

# Définir la fonction docker_logs_with_default en dehors du bloc conditionnel
docker_logs_with_default() {
  local args=("$@")
  if [[ ! " ${args[@]} " =~ " -n " ]]; then
    args+=("-n" "100")
  fi
  docker logs "${args[@]}"
}

# Maintenant, on configure les alias et la complétion
if command -v docker &> /dev/null; then
  alias drit="docker run -ti --rm"
  alias diel="docker exec -it \$(docker ps -ql)"
  alias dc="docker compose"
  
  alias dl="docker_logs_with_default"
  compdef _docker dl=docker

elif command -v nerdctl &> /dev/null; then
  alias drit="nerdctl run -ti --rm"
  alias diel="nerdctl exec -it \$(nerdctl ps -ql)"
  alias dc="nerdctl compose"
  alias docker=nerdctl

  docker_logs_with_default() {
    local args=("$@")
    if [[ ! " ${args[@]} " =~ " -n " ]]; then
      args+=("-n" "100")
    fi
    nerdctl logs "${args[@]}"
  }

  alias dl="docker_logs_with_default"
  compdef _docker dl=nerdctl

elif command -v podman &> /dev/null; then
  alias drit="podman run -ti --rm"
  alias diel="podman exec -it \$(podman ps -ql)"
  alias dc="podman compose"
  alias docker=podman

  docker_logs_with_default() {
    local args=("$@")
    if [[ ! " ${args[@]} " =~ " -n " ]]; then
      args+=("-n" "100")
    fi
    podman logs "${args[@]}"
  }

  alias dl="docker_logs_with_default"
  compdef _docker dl=podman
fi


alias yoink="open -a Yoink"
alias sk='ssh-keygen -R'

# Check if we are on macOS
# DISABLED
if [[ 0 == 1 && "$OSTYPE" == darwin* ]]; then
  # Check if 'gls' (GNU ls) is available
  if command -v gls >/dev/null 2>&1; then
    alias ls="gls --hyperlink=auto --color=tty"
  else
    # If 'gls' is not available, check if 'ls' is GNU ls
    if ls --version 2>/dev/null | grep -q "GNU coreutils"; then
      alias ls="ls --hyperlink=auto --color=tty"
    fi
  fi
# GNU Core Utilities aliases with existence checks
if command -v greadlink >/dev/null 2>&1; then alias readlink='greadlink'; fi
if command -v gdate >/dev/null 2>&1; then alias date='gdate'; fi
if command -v gdf >/dev/null 2>&1; then alias df='gdf'; fi
if command -v gdir >/dev/null 2>&1; then alias dir='gdir'; fi
if command -v gdircolors >/dev/null 2>&1; then alias dircolors='gdircolors'; fi
if command -v gvdir >/dev/null 2>&1; then alias vdir='gvdir'; fi
if command -v gecho >/dev/null 2>&1; then alias echo='gecho'; fi
if command -v gfalse >/dev/null 2>&1; then alias false='gfalse'; fi
if command -v gln >/dev/null 2>&1; then alias ln='gln'; fi
if command -v gmkdir >/dev/null 2>&1; then alias mkdir='gmkdir'; fi
if command -v gmknod >/dev/null 2>&1; then alias mknod='gmknod'; fi
if command -v gmkfifo >/dev/null 2>&1; then alias mkfifo='gmkfifo'; fi
if command -v gnice >/dev/null 2>&1; then alias nice='gnice'; fi
if command -v gpathchk >/dev/null 2>&1; then alias pathchk='gpathchk'; fi
if command -v gpinky >/dev/null 2>&1; then alias pinky='gpinky'; fi
if command -v gprintenv >/dev/null 2>&1; then alias printenv='gprintenv'; fi
if command -v gprintf >/dev/null 2>&1; then alias printf='gprintf'; fi
if command -v gpwd >/dev/null 2>&1; then alias pwd='gpwd'; fi
if command -v grmdir >/dev/null 2>&1; then alias rmdir='grmdir'; fi
if command -v gsleep >/dev/null 2>&1; then alias sleep='gsleep'; fi
if command -v gstat >/dev/null 2>&1; then alias stat='gstat'; fi
if command -v gsync >/dev/null 2>&1; then alias sync='gsync'; fi
if command -v gtouch >/dev/null 2>&1; then alias touch='gtouch'; fi
if command -v gtrue >/dev/null 2>&1; then alias true='gtrue'; fi
if command -v guname >/dev/null 2>&1; then alias uname='guname'; fi
if command -v gchgrp >/dev/null 2>&1; then alias chgrp='gchgrp'; fi
if command -v gchmod >/dev/null 2>&1; then alias chmod='gchmod'; fi
if command -v gchown >/dev/null 2>&1; then alias chown='gchown'; fi
if command -v ginstall >/dev/null 2>&1; then alias install='ginstall'; fi
if command -v gln >/dev/null 2>&1; then alias ln='gln'; fi
if command -v gcat >/dev/null 2>&1; then alias cat='gcat'; fi
if command -v gnl >/dev/null 2>&1; then alias nl='gnl'; fi
if command -v god >/dev/null 2>&1; then alias od='god'; fi
if command -v gpaste >/dev/null 2>&1; then alias paste='gpaste'; fi
if command -v gptx >/dev/null 2>&1; then alias ptx='gptx'; fi
if command -v gpr >/dev/null 2>&1; then alias pr='gpr'; fi
if command -v gsum >/dev/null 2>&1; then alias sum='gsum'; fi
if command -v gtac >/dev/null 2>&1; then alias tac='gtac'; fi
if command -v gtail >/dev/null 2>&1; then alias tail='gtail'; fi
if command -v gtr >/dev/null 2>&1; then alias tr='gtr'; fi
if command -v gbase32 >/dev/null 2>&1; then alias base32='gbase32'; fi
if command -v gbase64 >/dev/null 2>&1; then alias base64='gbase64'; fi
if command -v gcut >/dev/null 2>&1; then alias cut='gcut'; fi
if command -v gsplit >/dev/null 2>&1; then alias split='gsplit'; fi
if command -v gcsplit >/dev/null 2>&1; then alias csplit='gcsplit'; fi
if command -v gwc >/dev/null 2>&1; then alias wc='gwc'; fi
if command -v guniq >/dev/null 2>&1; then alias uniq='guniq'; fi
if command -v gcomm >/dev/null 2>&1; then alias comm='gcomm'; fi
if command -v gshuf >/dev/null 2>&1; then alias shuf='gshuf'; fi
if command -v gtee >/dev/null 2>&1; then alias tee='gtee'; fi
if command -v ghead >/dev/null 2>&1; then alias head='ghead'; fi
if command -v gjoin >/dev/null 2>&1; then alias join='gjoin'; fi
if command -v gsort >/dev/null 2>&1; then alias sort='gsort'; fi
if command -v gexpr >/dev/null 2>&1; then alias expr='gexpr'; fi
if command -v gfactor >/dev/null 2>&1; then alias factor='gfactor'; fi
if command -v gseq >/dev/null 2>&1; then alias seq='gseq'; fi
if command -v gtimeout >/dev/null 2>&1; then alias timeout='gtimeout'; fi
if command -v genv >/dev/null 2>&1; then alias env='genv'; fi
if command -v ggroups >/dev/null 2>&1; then alias groups='ggroups'; fi
if command -v gid >/dev/null 2>&1; then alias id='gid'; fi
if command -v gwhoami >/dev/null2>&1; then alias whoami='gwhoami'; fi
if command -v gdu >/dev/null 2>&1; then alias du='gdu'; fi
if command -v gkill >/dev/null 2>&1; then alias kill='gkill'; fi
if command -v gtest >/dev/null 2>&1; then alias test='gtest'; fi
if command -v gsha1sum >/dev/null 2>&1; then alias sha1sum='gsha1sum'; fi
if command -v gsha224sum >/dev/null 2>&1; then alias sha224sum='gsha224sum'; fi
if command -v gsha256sum >/dev/null 2>&1; then alias sha256sum='gsha256sum'; fi
if command -v gsha384sum >/dev/null 2>&1; then alias sha384sum='gsha384sum'; fi
if command -v gsha512sum >/dev/null 2>&1; then alias sha512sum='gsha512sum'; fi
if command -v gmd5sum >/dev/null 2>&1; then alias md5sum='gmd5sum'; fi
if command -v gcksum >/dev/null 2>&1; then alias cksum='gcksum'; fi
if command -v gwho >/dev/null 2>&1; then alias who='gwho'; fi
if command -v gw >/dev/null 2>&1; then alias w='gw'; fi
if command -v gusers >/dev/null 2>&1; then alias users='gusers'; fi


if ! command -v igrep >/dev/null 2>&1; then alias igrep='grep -i'; fi

#DISABLED
fi
#alias ls="l"

if [[ "$TERM" == "xterm-kitty" || "$TERM" == "kitty" ]]; then
	alias s="kitty +kitten ssh --kitten share_connections=yes"
	compdef _ssh s
	alias hg="kitty +kitten hyperlinked_grep"
	compdef _rg hg
	alias cb="kitty +kitten clipboard"
	# Set elsewhere to "exa"
	alias d="kitty +kitten diff"
	alias icat="kitty +kitten icat"
	alias transfer="kitty +kitten transfer"
	export EDITOR="kitten edit-in-kitty --type background"
	alias edit="kitten edit-in-kitty --type background"
	alias notify="kitten notify"

elif [[ "$WARP_IS_LOCAL_SHELL_SESSION" == "1" ]]; then
  alias s="ssh"
fi

alias pyenv="if [ ! -d .venv ]; then python3 -m venv .venv; fi && source .venv/bin/activate && if [ -f requirements.txt ]; then pip install -Ur requirements.txt; fi"
alias pyenv_tmp="tmp_dir=$(mktemp -d) && cd \$tmp_dir && python3 -m venv .venv && source .venv/bin/activate && if [ -f requirements.txt ]; then pip install -r requirements.txt; fi"

alias i='i --disable_telemetry'
alias interpreter='interpreter --disable_telemetry'
alias tmp='mkdir -p ~/tmp; cd ~/tmp'

# Colorize cat if colorize is installed and requirements are met
if command -v colorize_cat > /dev/null 2>&1 && colorize_check_requirements; then 
  function cat() {
    # If stdout is a terminal, use colorize_cat. Otherwise, fall back to /usr/bin/env cat.
    if [[ -t 1 ]]; then
        colorize_cat "$@"
      else
        /usr/bin/env cat "$@"
        return $?
    fi
  }
fi

# Start and follow a serfice
sjs() {
    sudo systemctl restart "$1" &
    sudo journalctl -fu "$1"
}




#alias cf='docker run --rm -it dpig/cloudflare-cli'
#alias docker='KUBECONFIG=~/.kube/config-small docker'

if command -v conda >/dev/null 2>&1; then
  eval "$(conda "shell.$(basename "${SHELL}")" hook)"
fi

if command -v nvim >/dev/null 2>&1; then
  alias vi=nvim
fi

#alias python=python3

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


# bw erreur punycode
export NODE_OPTIONS="--no-deprecation"

# Disable this stupid mouse capture of vim !
export VIMINIT='set mouse='

# Fig post block. Keep at the bottom of this file.
[[ -f "$HOME/.fig/shell/zshrc.post.zsh" ]] && builtin source "$HOME/.fig/shell/zshrc.post.zsh"

# Secretive Config
export SSH_AUTH_SOCK=/Users/obeone/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh

# Atiun

if [ -z "$HIST_IGNORE_ALL" ]; then
  if command -v atuin >/dev/null 2>&1; then
    eval "$(atuin init zsh --disable-up-arrow)"
    export ZSH_AUTOSUGGEST_STRATEGY=(atuin completion)
  fi

  alias histoff=' env HIST_IGNORE_ALL=true zsh'

else
  export HISTFILE=/dev/null

  alias histon=' exit'
fi


# Shell-GPT integration ZSH v0.2
_sgpt_zsh() {
if [[ -n "$BUFFER" ]]; then
    local _sgpt_prev_cmd=$BUFFER
    print -P "\e[90m# $_sgpt_prev_cmd\e[0m"  # Texte gris
    BUFFER+="⌛"
    zle -I && zle redisplay
    BUFFER=$(sgpt --shell --no-interaction <<< "$_sgpt_prev_cmd")
    zle end-of-line
fi
}
zle -N _sgpt_zsh
bindkey ^l _sgpt_zsh

# AiChat integration
_aichat_zsh() {
    if [[ -n "$BUFFER" ]]; then
        local _old=$BUFFER
        BUFFER+="⌛"
        zle -I && zle redisplay
        BUFFER=$(/opt/homebrew/bin/aichat -e "$_old" 2>> /tmp/aichat_debug.log)
        zle end-of-line
    fi
}

zle -N _aichat_zsh
bindkey '\ee' _aichat_zsh

export HF_HUB_ENABLE_HF_TRANSFER=1

# fpath cleanup
fpath_old=("$i{fpath[@]}")

# Exception of globing (wildcard etc) on commands
alias find="noglob find"

export DISABLE_TELEMETRY=true
export OLLAMA_NOHISTORY=true
alias gpt='sgpt'

# Lando
export PATH="/Users/obeone/.lando/bin${PATH+:$PATH}"; #landopath

if ! command -v sgpt >/dev/null 2>&1; then
    alias sgpt='docker run --rm -ti \
        --env OPENAI_API_KEY=$OPENAI_API_KEY \
        --env OS_NAME=$(uname -s) \
        --env SHELL_NAME=$(echo $SHELL) \
	--env DEFAULT_MODEL=gpt-4o \
        --volume gpt-cache:/tmp/shell_gpt \
	-v "$PWD:$PWD" \
	-v $HOME/.config/shell_gpt:/root/.config/shell_gpt/ \
    	--workdir "$PWD" \
        ghcr.io/ther1d/shell_gpt'
fi

alias docker-build-run='docker build . -t $(basename "$PWD" | tr " " "_") && docker run -it --rm $(basename "$PWD" | tr " " "_")'
ZSH_AUTOSUGGEST_IGNORE_WIDGETS+=(bracketed-paste)

