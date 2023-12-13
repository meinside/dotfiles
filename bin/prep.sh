#!/usr/bin/env bash

# bin/prep.sh
# 
# for cloning config files from github, and setting up several things
#
# (https://raw.githubusercontent.com/meinside/dotfiles/master/bin/prep.sh)
# 
# last update: 2023.12.13.

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

# check if it is me!
if [ "$(whoami)" == 'meinside' ]; then
	REPOSITORY="git@github.com:meinside/dotfiles.git"
else
	REPOSITORY="https://github.com/meinside/dotfiles.git"
fi
TMP_DIR="$HOME/configs.tmp"

info ">>> this script will setup several things for you..."
info

# authenticate for sudo if needed
if [ -z "$TERMUX_VERSION" ]; then  # not in termux
	sudo -l > /dev/null
fi

function pull_configs {
	check_git

	# clone config files
	rm -rf "$TMP_DIR" && \
		git clone $REPOSITORY "$TMP_DIR"

	# move temp files to $HOME directory
	shopt -s dotglob nullglob && \
		mv "$TMP_DIR"/* "$HOME"/ && \
		rm -rf "$TMP_DIR"
}

function check_git {
	warn ">>> checking git..."

	case "$OSTYPE" in
		linux*) check_git_linux ;;
	esac
}

function check_git_linux {
	if ! which git > /dev/null; then
		warning ">>> installing git..."

		if [ -z "$TERMUX_VERSION" ]; then
			if [ -x /usr/bin/apt-get ]; then
				sudo apt-get update && \
					sudo apt-get -y install git
			else
				error "* distro not supported"
			fi
		else  # termux
			pkg install git
		fi
	fi
}

function install_packages {
	warn ">>> installing other essential packages..."

	case "$OSTYPE" in
		darwin*) install_packages_macos ;;
		linux*) install_packages_linux ;;
		*) echo "* not supported yet: $OSTYPE" ;;
	esac
}

function install_packages_linux {
	if [ -z "$TERMUX_VERSION" ]; then
		if [ -x /usr/bin/apt-get ]; then
			sudo apt-get update && \
				sudo apt-get -y upgrade && \
				sudo apt-get -y install zsh vim tmux psmisc locales && \
				sudo locale-gen en_US.UTF-8
		else
			error "* distro not supported"
		fi
	else  # termux
		pkg install zsh tmux psmisc
	fi
}

function install_packages_macos {
	# install Homebrew
	/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
}

function cleanup {
	warn ">>> cleaning up..."

	case "$OSTYPE" in
		linux*) cleanup_linux ;;
	esac
}

function cleanup_linux {
	if [ -z "$TERMUX_VERSION" ]; then
		if [ -x /usr/bin/apt-get ]; then
			sudo apt-get -y autoremove && \
				sudo apt-get -y autoclean
		fi
	fi
}

function show_guide {
	case "$OSTYPE" in
		darwin*) show_guide_macos ;;
		linux*) show_guide_linux ;;
		*) error "* not supported yet: $OSTYPE" ;;
	esac
}

function show_guide_linux {
	error
	error "*** NOTICE: logout, and login again for reloading configs ***"
	error
}

function show_guide_macos {
	error
	error "*** logout, and login again for reloading configs ***"
	error
	info "for installing brew bundles:"
	info "  $ brew tap Homebrew/bundle"
	info "  $ brew bundle --file=$XDG_CONFIG_HOME/homebrew/Brewfile"
	info
}

pull_configs && \
	install_packages && \
	cleanup && \
	show_guide
