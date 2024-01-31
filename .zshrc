# .zshrc
#
# created on 2014.06.30.
# updated on 2024.01.31.
#
# $ chsh -s /usr/bin/zsh
#

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

export ZSH=$HOME/.oh-my-zsh

DISABLE_UPDATE_PROMPT="true"

# Uncomment following line if you want to disable autosetting terminal title.
DISABLE_AUTO_TITLE="true"

# oh-my-zsh theme
if [ -z $CONTAINER_ID ]; then
    ZSH_THEME="steeef" # when not in container (eg. distrobox)
else
    ZSH_THEME="strug"
fi

# Uncomment the following line to display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

HIST_STAMPS="yyyy-mm-dd"

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

# asdf-vm
export ASDF_DIR=$HOME/.asdf
export ASDF_CONFIG_FILE=$XDG_CONFIG_HOME/asdf/asdfrc
export ASDF_DEFAULT_TOOL_VERSIONS_FILENAME=$XDG_CONFIG_HOME/asdf/tool-versions

# oh-my-zsh plugins
plugins=(asdf colored-man-pages command-not-found copypath dotenv encode64 git git-flow history history-substring-search macos mosh nmap rust sudo urltools zsh-syntax-highlighting)

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
export HISTCONTROL=erasedups
export HISTSIZE=10000
export W3M_DIR="$XDG_STATE_HOME/w3m"

# colors
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

# brew
if [ -d /opt/homebrew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

######################
##  for development  #
######################

# NOTE: in termux, $PREFIX = '/data/data/com.termux/files/usr'

# for go
export GOPATH=$HOME/srcs/go
export PATH="$GOPATH/bin:$PATH"

# for lein (clojure)
export LEIN_JVM_OPTS=""
export LEIN_USE_BOOTCLASSPATH=no # https://github.com/venantius/ultra/issues/108

# for nodejs
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
if [ -d "$HOME/.local/share/npm/bin" ]; then
    export PATH="$HOME/.local/share/npm/bin:$PATH"
fi

# for ruby
export IRBRC="$XDG_CONFIG_HOME/irb/irbrc"
export SOLARGRAPH_CACHE="$XDG_CACHE_HOME/solargraph"

# for rust
if [ -d "$HOME/.cargo/bin" ]; then
    export PATH="$HOME/.cargo/bin:$PATH"
else
    for r in $HOME/.asdf/installs/rust/*; do
        if [ -d $r ]; then
            . "${r}/env"; break
        fi
    done
fi

# additional paths
export PATH="$HOME/bin:$HOME/.local/bin:$PATH"

# for asdf settings (handled by omz's 'asdf' plugin)
#if [ -d $HOME/.asdf ]; then
#    . $HOME/.asdf/asdf.sh
#
#    fpath=(${ASDF_DIR}/completions $fpath)  # append completions to fpath
#    autoload -Uz compinit && compinit   # initialise completions with ZSH's compinit
#fi


# aliases
. $XDG_CONFIG_HOME/aliases

# zsh functions
. $HOME/.zsh/func

# load custom environment variables (like GOPRIVATE, PATH, alias, ...) if exist
if [ -f $HOME/.custom_env ]; then
    . $HOME/.custom_env
fi

# remove redundant paths
typeset -aU path

# shell prompt
#
# (starship)
# $ cargo install starship --locked
if command -v starship &> /dev/null; then
    # config file in $HOME/.config/starship.toml
    eval "$(starship init zsh)"
else
    export PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME%%.*}: ${PWD/#$HOME/~}\007"; find_git_branch; find_git_dirty;'
fi

