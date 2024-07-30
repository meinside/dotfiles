#!/usr/bin/env bash

# bin/install_emacs.sh
# 
# For building emacs from source code.
#
# last update: 2024.07.30.


################################
#
# frequently updated values

# https://ftp.gnu.org/gnu/emacs/
EMACS_VERSION="29.4"	# XXX - edit for other versions


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
    if [ -t 0 ] && [ -t 1 ]; then
	echo -e "${RED}$1${RESET}"
    else
	echo "$1"
    fi
}
function info {
    if [ -t 0 ] && [ -t 1 ]; then
	echo -e "${GREEN}$1${RESET}"
    else
	echo "$1"
    fi
}
function warn {
    if [ -t 0 ] && [ -t 1 ]; then
	echo -e "${YELLOW}$1${RESET}"
    else
	echo "$1"
    fi
}

#
################################


LOCAL_INSTALL_DIR="$HOME/.local/emacs"
TMP_DIR="/tmp/emacs"

# check arguments
locally=false
for arg in "$@"; do
    case "$arg" in
	-l | --locally )
	    locally=true
	    ;;
    esac
done

function prep {
    # install needed packages
    if [ -x /usr/bin/apt-get ]; then
	sudo apt-get install -y libncurses-dev libgnutls28-dev gnutls-bin pkg-config texinfo libgccjit-13-dev libjansson-dev libtree-sitter-dev
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
    tar xzvf "emacs-${EMACS_VERSION}.tar.gz" && \
	cd "emacs-${EMACS_VERSION}/"

    if $locally; then
	warn ">>> building & installing binary locally..." && \
	    ./configure \
		--prefix="$LOCAL_INSTALL_DIR" \
		--without-x \
		--with-modules \
		--with-native-compilation \
		--with-xml2 \
		--with-json \
		--with-tree-sitter \
		CC="gcc-13" \
		CFLAGS="-O2 -pipe -march=native -fomit-frame-pointer" && \
	    make -j$(nproc) install
    else
	warn ">>> building & installing binary globally..." && \
	    ./configure \
		--without-x \
		--with-modules \
		--with-native-compilation \
		--with-xml2 \
		--with-json \
		--with-tree-sitter \
		CC="gcc-13" \
		CFLAGS="-O2 -pipe -march=native -fomit-frame-pointer" && \
	sudo make -j$(nproc) install
    fi
}

# clone, configure, build, and install
function install {
    warn ">>> installing emacs version ${EMACS_VERSION}..."

    SRC_TGZ="https://ftp.gnu.org/gnu/emacs/emacs-${EMACS_VERSION}.tar.gz"

    mkdir -p $TMP_DIR && \
	cd $TMP_DIR && \
	wget "$SRC_TGZ" && \
	make_install
}

# install for macOS
function install_macos {
    warn ">>> installing with brew..." && \
	brew install emacs
}

# install for linux
function install_linux {
    if [ -z "$TERMUX_VERSION" ]; then
	prep && \
	    install && \
	    clean
    else  # termux
	pkg install emacs
    fi
}

case "$OSTYPE" in
    darwin*) install_macos ;;
    linux*) install_linux ;;
    *) error "* not supported yet: $OSTYPE" ;;
esac

