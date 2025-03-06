# .bashrc
#
# created on 2012.05.31.
# updated on 2025.03.06.
#
# $ chsh -s `which zsh`
#

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
export HISTFILE="$XDG_STATE_HOME/bash/history"

# bash options
shopt -s histappend
shopt -s checkwinsize
shopt -s nullglob

# prompt
. "$HOME/.bash/colors"
. "$HOME/.bash/git-prompt"
case ${TERM} in
xterm* | rxvt* | Eterm | aterm | kterm | gnome* | screen*)
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

# ls colors
. "$XDG_CONFIG_HOME/lscolors"

# readline
export INPUTRC="$XDG_CONFIG_HOME/readline/inputrc"

# OS-specific settings
case "$OSTYPE" in
linux*) ;;
darwin*)
    #export CC="gcc-11"
    ;;
*) ;;
esac

# bash completion
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
    . /etc/bash_completion
fi

# homebrew on macOS
if [ -d /opt/homebrew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

######################
#
#  for development
#

# NOTE: in termux, $PREFIX = '/data/data/com.termux/files/usr'

# for go
export GOPATH="$HOME/srcs/go"
export PATH="$GOPATH/bin:$PATH"

# for lein (clojure)
export LEIN_JVM_OPTS=""
export LEIN_USE_BOOTCLASSPATH=no # https://github.com/venantius/ultra/issues/108
export LEIN_HOME="$XDG_DATA_HOME/lein"

# for nodejs
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
export NODE_REPL_HISTORY="$XDG_STATE_HOME/node_repl_history"
if [ -d "$HOME/.local/share/npm/bin" ]; then
    export PATH="$HOME/.local/share/npm/bin:$PATH"
fi

# for ruby
export IRBRC="$XDG_CONFIG_HOME/irb/irbrc"
export SOLARGRAPH_CACHE="$XDG_CACHE_HOME/solargraph"

# for rust
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
if [ -d "$CARGO_HOME/bin" ]; then
    export PATH="$CARGO_HOME/bin:$PATH"
else
    for r in "$HOME/.asdf/installs/rust"/*; do
        . "${r}/env"
        break
    done
fi

# for sqlite3
export SQLITE_HISTORY="$XDG_CACHE_HOME/sqlite_history"

# additional paths
export PATH="$HOME/bin:$HOME/.local/bin:$PATH"

# asdf settings
if [ -d "$XDG_DATA_HOME/asdf" ]; then
    export ASDF_DATA_DIR="$XDG_DATA_HOME/asdf"
    export ASDF_CONFIG_FILE=$XDG_CONFIG_HOME/asdf/asdfrc
    #export ASDF_DEFAULT_TOOL_VERSIONS_FILENAME=$XDG_CONFIG_HOME/asdf/tool-versions # FIXME
    export ASDF_DEFAULT_TOOL_VERSIONS_FILENAME=.config/asdf/tool-versions
    export PATH="$ASDF_DATA_DIR/shims:$ASDF_DATA_DIR/bin:$PATH"

    . <(asdf completion bash)
fi

#
######################

# aliases
. "$XDG_CONFIG_HOME/aliases"

# load custom environment variables (like GOPRIVATE, PATH, alias, ...) if exist
if [ -f "$HOME/.custom_env" ]; then
    . "$HOME/.custom_env"
fi

# run starship (not in containers)
#
# $ cargo install starship --locked
if [ -z $CONTAINER_ID ]; then
    if command -v starship &>/dev/null; then
        # config file in $HOME/.config/starship.toml
        eval "$(starship init zsh)"
    fi
fi
