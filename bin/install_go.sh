#!/usr/bin/env bash

# install_go.sh
# 
# Build and install Golang from the official repository.
#
# *** Note: this process needs much memory, so
# - assign GPU memory as little as possible,
# - or create a (temporary) swap partition.
#
# *** Another Note: `aarch64` is not supported in golang 1.4, so it will be bootstrapped with package manager's version.
# 
# created on : 2014.07.01.
# last update: 2020.12.21.
# 
# by meinside@gmail.com

# XXX - for making newly created files/directories less restrictive
umask 0022

# colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

TEMP_DIR="/tmp"
BOOTSTRAP_DIR="$TEMP_DIR/go-bootstrap"
INSTALLATION_DIR="/opt"

REPOSITORY="https://go.googlesource.com/go"
BOOTSTRAP_BRANCH="release-branch.go1.4"

# XXX - edit for different version of Go (see: https://go.googlesource.com/go/+refs)
#INSTALL_BRANCH="release-branch.go1.6"	# branch
INSTALL_BRANCH="go1.15.6"	# tag

function prep {
	# install essential packages
	echo -e "${YELLOW}>>> Installing essential packages...${RESET}"

	sudo apt-get install -y git gcc libc6-dev
}

function clone_bootstrap_repo {
	# clone the repository
	echo -e "${YELLOW}>>> Cloning repository for boostrap($BOOTSTRAP_BRANCH)...${RESET}"

	rm -rf "$BOOTSTRAP_DIR" && \
		git clone -b "$BOOTSTRAP_BRANCH" "$REPOSITORY" "$BOOTSTRAP_DIR"
}

function build_bootstrap {
	# build
	echo -e "${YELLOW}>>> Building...${RESET}"

	cd "$BOOTSTRAP_DIR/src" && ./make.bash

	if [ -x "$BOOTSTRAP_DIR/bin/go" ]; then
		echo -e "${YELLOW}>>> Go for bootstrap was installed at: $BOOTSTRAP_DIR${RESET}"
	else
		echo -e "${RED}>>> Failed to build Go for bootstrap at: $BOOTSTRAP_DIR${RESET}"
		exit 1
	fi
}

# build Go (for bootstrap)
function bootstrap {
	# if Go (for bootstrap) already exists,
	if [ -d "$INSTALLATION_DIR/go" ]; then
		# reuse it
		echo -e "${YELLOW}>>> Reusing Go at: $INSTALLATION_DIR/go${RESET}"

		ln -sf "$INSTALLATION_DIR/go" "$BOOTSTRAP_DIR"
	else
		arch=`uname -m`
		if [[ $arch == "aarch64" ]]; then
			echo -e "${RED}>>> Go 1.4 does not support $arch.${RESET}"

			echo -e "${YELLOW}>>> Installing Go from the package manager...${RESET}"

			# install golang from the package manager
			sudo apt-get -y install golang

			BOOTSTRAP_DIR=/usr/lib/go
		else
			clone_bootstrap_repo && build_bootstrap
		fi
	fi
}

# clean Go (for bootstrap)
function clean_bootstrap {
	arch=`uname -m`
	if [[ $arch == "aarch64" ]]; then
		echo -e "${YELLOW}>>> Uninstalling package manager's Go...${RESET}"

		# uninstall the package manager's golang
		sudo apt-get -y purge golang
		sudo apt-get -y autoremove
	else
		# remove bootstrap go
		echo -e "${YELLOW}>>> Cleaning Go bootstrap at: $BOOTSTRAP_DIR${RESET}"
		rm -rf "$BOOTSTRAP_DIR"
	fi
}

function clone_repo {
	echo -e "${YELLOW}>>> Cloning repository...(branch/tag: $INSTALL_BRANCH)${RESET}"

	SRC_DIR="$TEMP_DIR/go-$INSTALL_BRANCH"

	# clone the repository
	rm -rf "$SRC_DIR" && \
		git clone -b "$INSTALL_BRANCH" "$REPOSITORY" "$SRC_DIR"
}

function build {
	echo -e "${YELLOW}>>> Building Go with bootstrap Go...${RESET}"

	# build
	cd "$SRC_DIR/src" && \
		GOROOT_BOOTSTRAP=$BOOTSTRAP_DIR ./make.bash
	
	# delete unneeded files
	rm -rf "$SRC_DIR/.git" "$SRC_DIR/pkg/bootstrap" "$SRC_DIR/pkg/obj"
}

function install {
	echo -e "${YELLOW}>>> Installing...${RESET}"

	GO_DIR="$INSTALLATION_DIR/go-$INSTALL_BRANCH"

	# install
	cd ../.. && \
		sudo mv "$SRC_DIR" "$GO_DIR" && \
		sudo chown -R "$USER" "$GO_DIR" && \
		sudo ln -sfn "$GO_DIR" "$INSTALLATION_DIR/go"
}

# install Go
function install_go {
	clone_repo && build && install && \
		echo -e "${GREEN}>>> Go with branch/tag: $INSTALL_BRANCH was installed at: $GO_DIR${RESET}"
}

# for macOS
function install_go_macos {
	brew install go
}

# for linux
function install_go_linux {
	prep && bootstrap && install_go && clean_bootstrap
}

case "$OSTYPE" in
	darwin*) install_go_macos ;;
	linux*) install_go_linux ;;
	*) echo "* Unsupported os type: $OSTYPE" ;;
esac

