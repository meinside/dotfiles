# .bashrc
#
# created on 2012.05.31.
# updated on 2022.04.15.
#
# ... by meinside@gmail.com

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# various configurations
export DISPLAY=:0.0
export EDITOR="/usr/bin/vim"
export SVN_EDITOR="/usr/bin/vim"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export CLICOLOR=true
export TERM="xterm-256color" # XXX: set terminal setting to 'xterm-256color' for italic fonts

HISTCONTROL=ignoreboth

shopt -s histappend
shopt -s checkwinsize

# prompt
source ~/.bash/colors
source ~/.bash/git-prompt
case ${TERM} in
    xterm*|rxvt*|Eterm|aterm|kterm|gnome*|screen*)
        if [ `whoami` = "root" ]; then
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

# bash completion
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
    . /etc/bash_completion
fi

######################
##  for development  #
######################

if [[ -z $TMUX ]]; then

    # NOTE: in termux, $PREFIX = '/data/data/com.termux/files/usr'

    # for Go
    if [ -x "`which go`" ]; then
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

    # for Lua
    if [ -d /opt/lua-language-server/bin ]; then
        export PATH=$PATH:/opt/lua-language-server/bin
    fi

    # for Rust
    if [ -d "$HOME/.cargo/bin" ]; then
        . "$HOME/.cargo/env"
    fi

    # for Zig
    if [ -d /opt/zig ]; then
        export PATH=$PATH:/opt/zls/zig-out/bin
    fi

    # additional paths
    export PATH="$PATH:$HOME/bin:$HOME/.local/bin:$PATH"

    # asdf settings
    if [ -d ~/.asdf ]; then
        . $HOME/.asdf/asdf.sh
        . $HOME/.asdf/completions/asdf.bash
    fi

fi

# aliases
. ~/.aliases

# load custom environment variables (like GOPRIVATE, PATH, alias, ...) if exist
if [ -f ~/.custom_env ]; then
    . ~/.custom_env
fi

