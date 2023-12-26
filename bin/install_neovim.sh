#!/usr/bin/env bash

# bin/install_neovim.sh
# 
# For building neovim from source code.
# (https://github.com/neovim/neovim/wiki/Installing-Neovim#install-from-source)
#
# last update: 2023.12.26.

# * To install nightly version:
#
#   $ ./install_neovim.sh --nightly
#
#
# * To install locally (for distrobox, etc.):
#
#   $ ./install_neovim.sh --locally
#
#
# * To uninstall:
#
#   $ sudo rm /usr/local/bin/nvim
#   $ sudo rm -r /usr/local/share/nvim/
#
#   or
#
#   $ rm -rf ~/.local/nvim
#
#
# * To install tree-sitter:
#
#   $ cargo install tree-sitter-cli
#   or
#   $ npm -g install tree-sitter-cli


################################
#
# frequently updated values

# https://github.com/neovim/neovim/releases
NVIM_VERSION="v0.9.4"	# XXX - edit for other versions


################################
#
# common functions and variables

# XXX - for making newly created files/directories less restrictive
umask 0022

# colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

# functions for pretty-printing
function error {
    echo -e "${RED}$1${RESET}"
}
function info {
    echo -e "${GREEN}$1${RESET}"
}
function warn {
    echo -e "${YELLOW}$1${RESET}"
}

#
################################


LOCAL_INSTALL_DIR="$HOME/.local/nvim"
TMP_DIR="/tmp/nvim"

# check arguments
nightly=false
locally=false
for arg in "$@"; do
    case "$arg" in
	-n | --nightly )
	    nightly=true
	    ;;
	-l | --locally )
	    locally=true
	    ;;
    esac
done

function prep {
    # install needed packages
    if [ -x /usr/bin/apt-get ]; then
	sudo apt-get install -y ninja-build gettext libtool libtool-bin autoconf automake cmake g++ pkg-config unzip
    elif [ -x /usr/bin/pacman ]; then
	sudo pacman -Syu ninja gettext libtool autoconf automake cmake pkg-config unzip
    else
	error "* distro not supported"
    fi

    # clean tmp directory
    clean
}

function clean {
    sudo rm -rf $TMP_DIR
}

function make_install {
    buildtype="Release"
    if $nightly; then
	buildtype="RelWithDebInfo"
    fi

    if $locally; then
	warn ">>> installing binary locally..." && \
	    make CMAKE_BUILD_TYPE="$buildtype" CMAKE_INSTALL_PREFIX="$LOCAL_INSTALL_DIR" install
    else
	warn ">>> installing binary globally..." && \
	    sudo CMAKE_BUILD_TYPE="$buildtype" make install
    fi
}

# clone, configure, build, and install
function install {
    tag=$NVIM_VERSION
    if $nightly; then
	tag="nightly"
    fi

    warn ">>> installing neovim version ${tag}..."

    unset LUA_PATH
    unset LUA_CPATH

    git clone https://github.com/neovim/neovim.git $TMP_DIR && \
	cd $TMP_DIR && \
	git checkout ${tag} && \
	rm -rf build && \
	make_install
}

# install for macOS
function install_macos {
    if $locally; then
	warn ">>> installing HEAD with brew..." && \
	    brew install neovim --HEAD
    else
	warn ">>> installing with brew..." && \
	    brew install neovim
    fi
}

# install for linux
function install_linux {
    if [ -z "$TERMUX_VERSION" ]; then
	prep && \
	    install && \
	    clean && \
	    update_alternatives
    else  # termux
	pkg install neovim
    fi
}

# update alternatives for `vi(m)`
function update_alternatives {
    if [ -x /usr/bin/update-alternatives ]; then
	if $locally; then
	    NVIM_BIN_PATH="$LOCAL_INSTALL_DIR/bin/nvim"
	    warn ">>> updating alternatives for vi(m) to locally installed neovim: $NVIM_BIN_PATH"
	else
	    NVIM_BIN_PATH="/usr/local/bin/nvim"
	    warn ">>> updating alternatives for vi(m) to: $NVIM_BIN_PATH"
	fi

	sudo update-alternatives --install /usr/bin/vi vi "$NVIM_BIN_PATH" 60 && \
	    sudo update-alternatives --set vi "$NVIM_BIN_PATH" && \
	    sudo update-alternatives --install /usr/bin/vim vim "$NVIM_BIN_PATH" 60 && \
	    sudo update-alternatives --set vim "$NVIM_BIN_PATH" && \
	    sudo update-alternatives --install /usr/bin/editor editor "$NVIM_BIN_PATH" 60 && \
	    sudo update-alternatives --set editor "$NVIM_BIN_PATH"
    fi
}

case "$OSTYPE" in
    darwin*) install_macos ;;
    linux*) install_linux ;;
    *) error "* not supported yet: $OSTYPE" ;;
esac

