# .zshrc
#
# created on 2014.06.30.
# updated on 2025.05.22.
#
# $ chsh -s `which zsh`
#

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# oh-my-zsh location
export ZSH=$HOME/.oh-my-zsh

# oh-my-zsh theme
if [ -z $CONTAINER_ID ]; then
    ZSH_THEME="steeef" # when not in container (eg. distrobox)
else
    ZSH_THEME="strug"
fi

DISABLE_UPDATE_PROMPT="true"
DISABLE_AUTO_TITLE="true"
COMPLETION_WAITING_DOTS="true"

# zsh history
HIST_STAMPS="yyyy-mm-dd"
HISTSIZE=10000
SAVEHIST=10000
HISTORY_IGNORE="(ls|cd|pwd|exit|clear)*"
setopt EXTENDED_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS
setopt HIST_NO_STORE
setopt HIST_REDUCE_BLANKS

# comply with XDG base directory specification
if [[ -z "$XDG_CONFIG_HOME" ]]; then
    export XDG_CONFIG_HOME="$HOME/.config"
fi
if [[ -z "$XDG_DATA_HOME" ]]; then
    export XDG_DATA_HOME="$HOME/.local/share"
fi
if [[ -z "$XDG_STATE_HOME" ]]; then
    export XDG_STATE_HOME="$HOME/.local/state"
fi
if [[ -z "$XDG_CACHE_HOME" ]]; then
    export XDG_CACHE_HOME="$HOME/.cache"
fi

# zsh history file
ZSH_HISTORY_DIR="$XDG_STATE_HOME/zsh"
if [[ ! -d $ZSH_HISTORY_DIR ]]; then
    mkdir -p $ZSH_HISTORY_DIR
fi
HISTFILE="$ZSH_HISTORY_DIR/history"

# homebrew on macOS
if [ -d /opt/homebrew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# asdf-vm
export ASDF_DATA_DIR="$XDG_DATA_HOME/asdf"
export ASDF_CONFIG_FILE=$XDG_CONFIG_HOME/asdf/asdfrc
#export ASDF_DEFAULT_TOOL_VERSIONS_FILENAME=$XDG_CONFIG_HOME/asdf/tool-versions # FIXME
export ASDF_DEFAULT_TOOL_VERSIONS_FILENAME=.config/asdf/tool-versions
export PATH="$ASDF_DATA_DIR/shims:$ASDF_DATA_DIR/bin:$PATH"

# oh-my-zsh plugins
plugins=(
    aliases # `als`
    alias-finder
    asdf
    aws
    brew
    colored-man-pages
    colorize
    command-not-found
    dotenv
    encode64 # `encode64`, `encodefile64`, `decode64`
    extract # `extract`
    git
    git-flow
    golang
    history
    history-substring-search
    macos
    mosh
    nmap
    npm
    qrcode # `qrcode`, `qrsvg`
    rust
    ssh
    sudo
    systemd
    tailscale
    tmux
    ubuntu
    urltools # `urlencode`, `urldecode`
    zsh-syntax-highlighting
)

# oh-my-zsh plugins' configurations
zstyle ':omz:plugins:alias-finder' autoload yes

# Search for oh-my-zsh.sh
if ! [ -f $ZSH/oh-my-zsh.sh ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" -s '--keep-zshrc'
fi
. $ZSH/oh-my-zsh.sh

# Setup for zsh-syntax-highlighting
if ! [ -d ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
fi

# User configurations
#umask 027
export DISPLAY=:0.0
export EDITOR="/usr/bin/vim"
export SVN_EDITOR="$EDITOR"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export CLICOLOR=true
if [ -z "$TMUX" ]; then
    if [[ $TERM != "xterm-kitty" ]]; then
        export TERM="xterm-256color"
    fi
fi
export W3M_DIR="$XDG_STATE_HOME/w3m"

# ls colors
. $XDG_CONFIG_HOME/lscolors

# readline
export INPUTRC="$XDG_CONFIG_HOME/readline/inputrc"

# OS-specific settings
case "$OSTYPE" in
    linux*)
        ;;
    darwin*)
        #export CC="gcc-11"
        ;;
    *)
        ;;
esac

# key bindings
bindkey -v
bindkey "^A" vi-beginning-of-line
bindkey "^E" vi-end-of-line
bindkey "^K" kill-line
bindkey "^D" delete-char
bindkey "^F" vi-forward-char
bindkey "^B" vi-backward-char
bindkey '^[[A' history-beginning-search-backward
bindkey "^N" history-beginning-search-forward

# zsh options
unsetopt nomatch


######################
#
#  for development
#

# NOTE: in termux, $PREFIX = '/data/data/com.termux/files/usr'

# for go
export GOPATH=$HOME/srcs/go
if [ -d "$GOPATH/bin" ]; then
    export PATH="$PATH:$GOPATH/bin"
fi

# for lein (clojure)
export LEIN_JVM_OPTS=""
export LEIN_USE_BOOTCLASSPATH=no # https://github.com/venantius/ultra/issues/108
export LEIN_HOME="$XDG_DATA_HOME/lein"

# for nodejs
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
export NODE_REPL_HISTORY="$XDG_STATE_HOME/node_repl_history"
if [ -d "$HOME/.local/share/npm/bin" ]; then
    export PATH="$PATH:$HOME/.local/share/npm/bin"
fi

# for ruby
export IRBRC="$XDG_CONFIG_HOME/irb/irbrc"
export SOLARGRAPH_CACHE="$XDG_CACHE_HOME/solargraph"

# for rust
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
if [ -d "$CARGO_HOME/bin" ]; then
    export PATH="$PATH:$CARGO_HOME/bin"
fi
for r in $ASDF_DATA_DIR/installs/rust/*; do
    if [ -d $r ]; then
        . "${r}/env"; break
    fi
done

# for sqlite3
export SQLITE_HISTORY="$XDG_CACHE_HOME/sqlite_history"

# additional paths
export PATH="$HOME/bin:$HOME/.local/bin:$PATH"

# for asdf settings (handled by omz's 'asdf' plugin)
#if [ -d $ASDF_DATA_DIR ]; then
#    fpath=(${ASDF_DATA_DIR:-$HOME/.asdf}/completions $fpath)
#    autoload -Uz compinit && compinit
#fi

#
######################


# aliases
. $XDG_CONFIG_HOME/aliases

# zsh functions
. $HOME/.zsh/func

# load custom environment variables (like GOPRIVATE, PATH, alias, ...) if exist
if [ -f $HOME/.custom_env ]; then
    # sample in $HOME/.custom_env.sample
    . $HOME/.custom_env
fi

# remove redundant paths
typeset -aU path


# run starship (not in containers)
#
# $ cargo install starship --locked
if [ -z $CONTAINER_ID ]; then
    if command -v starship &> /dev/null; then
        # config file in $HOME/.config/starship.toml
        eval "$(starship init zsh)"
    fi
fi

