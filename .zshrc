# .zshrc
#
# created on 2014.06.30.
# updated on 2021.11.08.
#
# ... by meinside@gmail.com
#
# $ chsh -s /bin/zsh
#

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# Path to your oh-my-zsh installation.
# (https://github.com/robbyrussell/oh-my-zsh)
export ZSH=$HOME/.oh-my-zsh

# If you would like oh-my-zsh to automatically update itself
# without prompting you
DISABLE_UPDATE_PROMPT="true"

# Uncomment following line if you want to disable autosetting terminal title.
DISABLE_AUTO_TITLE="true"

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="steeef"

# Uncomment the following line to display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
HIST_STAMPS="yyyy-mm-dd"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(macos history history-substring-search mosh git git-flow docker copydir colored-man-pages encode64 urltools sudo web-search)

# Search for oh-my-zsh.sh
if ! [ -f $ZSH/oh-my-zsh.sh ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" -s '--keep-zshrc'
fi
source $ZSH/oh-my-zsh.sh

# User configuration
#umask 027
export DISPLAY=:0.0
export EDITOR="/usr/bin/vim"
export SVN_EDITOR="/usr/bin/vim"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export CLICOLOR=true
export TERM="xterm-256color" # XXX: set terminal setting to 'xterm-256color' for italic fonts
export HISTCONTROL=erasedups
export HISTSIZE=10000

# prompt
export PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME%%.*}: ${PWD/#$HOME/~}\007"; find_git_branch; find_git_dirty;'

# colors
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep="grep --color=auto"
fi

# OS-specific settings
case "$OSTYPE" in
    linux*)
        ;;
    darwin*)
        export CC="gcc-11"
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

######################
##  for development  #
######################

if [[ -z $TMUX ]]; then

    # for Babashka
    if [ -d /opt/babashka ]; then
        export PATH=$PATH:/opt/babashka
    fi

    # for Go
    if [ -d /opt/go/bin ]; then
        export GOROOT=/opt/go
    elif [ -x "`which go`" ]; then
        export GOROOT=`go env GOROOT`
    fi
    if [ -d $GOROOT ]; then
        export GOPATH=$HOME/srcs/go
        export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
    fi

    # for Haskell
    [ -f "$HOME/.ghcup/env" ] && source "$HOME/.ghcup/env" # ghcup-env

    # for Lein (Clojure)
    export LEIN_JVM_OPTS=""
    # https://github.com/venantius/ultra/issues/108
    export LEIN_USE_BOOTCLASSPATH=no

    # for Node.js
    if [ -d /opt/node/bin ]; then
        export PATH=$PATH:/opt/node/bin
    fi

    # for Ruby (RVM)
    [[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

    # for Rust
    if [ -d "$HOME/.cargo/bin" ]; then
        export PATH=$PATH:$HOME/.cargo/bin
    fi

    # for Zig
    if [ -d /opt/zig ]; then
        export PATH=$PATH:/opt/zig
    fi

    # additional paths
    export PATH="$PATH:$HOME/bin:$HOME/.local/bin"

fi

# for python and virtualenv
#
# $ sudo apt-get install python3-pip
# $ sudo pip3 install virtualenvwrapper
export WORKON_HOME=$HOME/.virtualenvs
[[ -s "/usr/local/bin/virtualenvwrapper.sh" ]] && source "/usr/local/bin/virtualenvwrapper.sh"	# virtualenv and virtualenvwrapper

# for zsh-syntax-highlighting
if [ -d /usr/share/zsh-syntax-highlighting/ ]; then
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
elif [ -d /usr/local/share/zsh-syntax-highlighting/ ]; then
    source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# aliases
. ~/.aliases

# zsh functions
. ~/.zshfunc

# load custom environment variables (like GOPRIVATE, PATH, alias, ...) if exist
if [ -f ~/.custom_env ]; then
    . ~/.custom_env
fi

# remove redundant paths
typeset -aU path

