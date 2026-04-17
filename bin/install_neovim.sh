#!/usr/bin/env bash

# bin/install_neovim.sh
#
# For building neovim from source code.
# (https://github.com/neovim/neovim/wiki/Installing-Neovim#install-from-source)
#
# last update: 2026.04.17.

set -euo pipefail

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
readonly NVIM_VERSION="v0.12.1" # XXX - edit for other versions

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

readonly LOCAL_INSTALL_DIR="$HOME/.local/nvim"
readonly TMP_DIR="/tmp/nvim"

# check arguments
nightly=false
locally=false
for arg in "$@"; do
	case "$arg" in
	-n | --nightly)
		nightly=true
		;;
	-l | --locally)
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
		return 1
	fi

	# clean tmp directory
	clean
}

function clean {
	sudo rm -rf "$TMP_DIR"
}

function make_install {
	local buildtype="Release"
	if $nightly; then
		buildtype="RelWithDebInfo"
	fi

	if $locally; then
		warn ">>> installing binary locally..."
		make CMAKE_BUILD_TYPE="$buildtype" CMAKE_INSTALL_PREFIX="$LOCAL_INSTALL_DIR" install
	else
		warn ">>> installing binary globally..."
		# NOTE: pass CMAKE_BUILD_TYPE as a make argument (not as a shell env)
		# so sudo's default env_reset doesn't strip it.
		sudo make CMAKE_BUILD_TYPE="$buildtype" install
	fi
}

# clone, configure, build, and install
function install {
	local tag="$NVIM_VERSION"
	if $nightly; then
		tag="nightly"
	fi

	warn ">>> installing neovim version ${tag}..."

	unset LUA_PATH
	unset LUA_CPATH

	git clone https://github.com/neovim/neovim.git "$TMP_DIR"
	cd "$TMP_DIR"
	git checkout "${tag}"
	rm -rf build
	make_install
}

# install for macOS
function install_macos {
	if $nightly; then
		warn ">>> installing HEAD with brew..."
		brew install neovim --HEAD
	else
		warn ">>> installing with brew..."
		brew install neovim
	fi
}

# install for linux
function install_linux {
	prep
	install
	clean
	update_alternatives
}

# install for termux
function install_termux {
	pkg install neovim
}

# update alternatives for `vi(m)`
function update_alternatives {
	if [ -x /usr/bin/update-alternatives ]; then
		local nvim_bin_path
		if $locally; then
			nvim_bin_path="$LOCAL_INSTALL_DIR/bin/nvim"
			warn ">>> updating alternatives for vi(m) to locally installed neovim: $nvim_bin_path"
		else
			nvim_bin_path="/usr/local/bin/nvim"
			warn ">>> updating alternatives for vi(m) to: $nvim_bin_path"
		fi

		sudo update-alternatives --install /usr/bin/vi vi "$nvim_bin_path" 60
		sudo update-alternatives --set vi "$nvim_bin_path"
		sudo update-alternatives --install /usr/bin/vim vim "$nvim_bin_path" 60
		sudo update-alternatives --set vim "$nvim_bin_path"
		sudo update-alternatives --install /usr/bin/editor editor "$nvim_bin_path" 60
		sudo update-alternatives --set editor "$nvim_bin_path"
	fi
}

case "$OSTYPE" in
darwin*) install_macos ;;
linux-android) install_termux ;;
linux*) install_linux ;;
*) error "* not supported yet: $OSTYPE" ;;
esac
