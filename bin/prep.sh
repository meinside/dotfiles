#!/usr/bin/env bash

# prep.sh
# 
# for cloning config files from github, and setting up several things
#
# (https://raw.githubusercontent.com/meinside/dotfiles/master/bin/prep.sh)
# 
# last update: 2021.09.10.
# 
# by meinside@gmail.com

# colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

if [ `whoami` == 'meinside' ]; then
	REPOSITORY="git@github.com:meinside/dotfiles.git"
else
	REPOSITORY="https://github.com/meinside/dotfiles.git"
fi
TMP_DIR="$HOME/configs.tmp"

echo -e "${GREEN}>>> This script will setup several things for you...${RESET}\n"

# authenticate for sudo if needed
if [ -z $TERMUX_VERSION ]; then  # not in termux
	sudo -l > /dev/null
fi

function pull_configs {
	check_git

	# clone config files
	rm -rf $TMP_DIR
	git clone $REPOSITORY $TMP_DIR

	# move temp files to $HOME directory
	shopt -s dotglob nullglob
	mv $TMP_DIR/* $HOME/
	rm -rf $TMP_DIR
}

function check_git {
	echo -e "${YELLOW}>>> Checking git...${RESET}"

	case "$OSTYPE" in
		linux*) check_git_linux ;;
	esac
}

function check_git_linux {
	if ! which git > /dev/null; then
		echo -e "${YELLOW}>>> Installing git...${RESET}"

		if [ -z $TERMUX_VERSION ]; then
			sudo apt-get update
			sudo apt-get -y install git
		else  # termux
			pkg install git
		fi
	fi
}

function install_packages {
	echo -e "${YELLOW}>>> Installing other essential packages...${RESET}"

	case "$OSTYPE" in
		darwin*) install_packages_macos ;;
		linux*) install_packages_linux ;;
		*) echo "* Unsupported os type: $OSTYPE" ;;
	esac
}

function install_packages_linux {
	if [ -z $TERMUX_VERSION ]; then
		sudo apt-get update
		sudo apt-get -y upgrade
		sudo apt-get -y install zsh vim tmux psmisc
	else  # termux
		pkg install zsh tmux psmisc
	fi
}

function install_packages_macos {
	# install Homebrew
	/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
}

function cleanup {
	echo -e "${YELLOW}>>> Cleaning up...${RESET}"

	case "$OSTYPE" in
		linux*) cleanup_linux ;;
	esac
}

function cleanup_linux {
	if [ -z $TERMUX_VERSION ]; then
		sudo apt-get -y autoremove
		sudo apt-get -y autoclean
	fi
}

function show_guide {
	case "$OSTYPE" in
		darwin*) show_guide_macos ;;
		linux*) show_guide_linux ;;
		*) echo "* Unsupported os type: $OSTYPE" ;;
	esac
}

function show_guide_linux {
	echo
	echo -e "${RED}*** NOTICE: logout, and login again for reloading configs ***${RESET}"
	echo
}

function show_guide_macos {
	echo
	echo -e "${RED}*** Logout, and login again for reloading configs ***${RESET}"
	echo
	echo -e "${GREEN}For installing brew bundles: ${RESET}"
	echo -e "${GREEN}  $ brew tap Homebrew/bundle ${RESET}"
	echo -e "${GREEN}  $ brew bundle ${RESET}"
	echo
}

pull_configs && \
	install_packages && \
	cleanup && \
	show_guide
