# .bashrc
#
# created on 2012.05.31.
# updated on 2023.09.05.

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

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

# various configurations
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
export HISTCONTROL=ignoreboth

# bash options
shopt -s histappend
shopt -s checkwinsize
shopt -s nullglob

# prompt
. "$HOME/.bash/colors"
. "$HOME/.bash/git-prompt"
case ${TERM} in
    xterm*|rxvt*|Eterm|aterm|kterm|gnome*|screen*)
        if [ "$(whoami)" = "root" ]; then
            PS1="\[$bldred\]\u@\h\[$txtrst\]:\[$bldblu\]\w\[$txtgrn\]\$git_branch\[$txtylw\]\$git_dirty\[$txtrst\]\$ "
        else
            PS1="\[$bldgrn\]\u@\h\[$txtrst\]:\[$bldblu\]\w\[$txtgrn\]\$git_branch\[$txtylw\]\$git_dirty\[$txtrst\]\$ "
        fi
        ;;
    *)
        PS1='\u@\h \w \$ '
        ;;
esac
export PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME%%.*}: ${PWD/#$HOME/~}\007"; find_git_branch; find_git_dirty;'

# colors
. "$XDG_CONFIG_HOME/lscolors"

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

# bash completion
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
    . /etc/bash_completion
fi

######################
##  for development  #
######################

if [[ -z $TMUX ]]; then

    # NOTE: in termux, $PREFIX = '/data/data/com.termux/files/usr'

    # brew
    if [ -d /opt/homebrew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    # for go
    export GOPATH=$HOME/srcs/go
    export PATH=$PATH:$GOPATH/bin

    # for lein (clojure)
    export LEIN_JVM_OPTS=""
    export LEIN_USE_BOOTCLASSPATH=no # https://github.com/venantius/ultra/issues/108

    # for nodejs
    export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
    if [ -d "$HOME/.local/share/npm/bin" ]; then
        export PATH=$PATH:.local/share/npm/bin
    fi

    # for ruby
    export IRBRC="$XDG_CONFIG_HOME/irb/irbrc"
    export SOLARGRAPH_CACHE="$XDG_CACHE_HOME/solargraph"

    # for rust
    if [ -d "$HOME/.cargo/bin" ]; then
        export PATH="$HOME/.cargo/bin:$PATH"
    else
        for r in "$HOME/.asdf/installs/rust"/*; do
            . "${r}/env"; break
        done
    fi

    # for zig
    if [ -d /opt/zig ]; then
        export PATH=$PATH:/opt/zls/zig-out/bin
    fi

    # additional paths
    export PATH="$HOME/bin:$HOME/.local/bin:$PATH"

    # asdf settings
    if [ -d ~/.asdf ]; then
        . "$HOME/.asdf/asdf.sh"
        . "$HOME/.asdf/completions/asdf.bash"
    fi

fi

# aliases
. "$XDG_CONFIG_HOME/aliases"

# load custom environment variables (like GOPRIVATE, PATH, alias, ...) if exist
if [ -f ~/.custom_env ]; then
    . "$HOME/.custom_env"
fi

