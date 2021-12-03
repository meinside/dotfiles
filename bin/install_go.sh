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
# last update: 2021.12.03.
# 
# by meinside@gmail.com


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


TEMP_DIR="/tmp"
BOOTSTRAP_DIR="$TEMP_DIR/go-bootstrap"
INSTALLATION_DIR="/opt"

REPOSITORY="https://go.googlesource.com/go"
BOOTSTRAP_BRANCH="release-branch.go1.4"

# XXX - edit for different version of Go (see: https://go.googlesource.com/go/+refs)
#INSTALL_BRANCH="release-branch.go1.6"	# branch
INSTALL_BRANCH="go1.17.3"	# tag

function prep {
	# install essential packages
	warn ">>> installing essential packages..."

	sudo apt-get install -y git gcc libc6-dev
}

function clone_bootstrap_repo {
	# clone the repository
	warn ">>> cloning repository for boostrap($BOOTSTRAP_BRANCH)..."

	rm -rf "$BOOTSTRAP_DIR" && \
		git clone -b "$BOOTSTRAP_BRANCH" "$REPOSITORY" "$BOOTSTRAP_DIR"
}

function build_bootstrap {
	# build
	warn ">>> building..."

	cd "$BOOTSTRAP_DIR/src" && ./make.bash

	if [ -x "$BOOTSTRAP_DIR/bin/go" ]; then
		warn ">>> go for bootstrap was installed at: $BOOTSTRAP_DIR$"
	else
		error ">>> failed to build go for bootstrap at: $BOOTSTRAP_DIR"
		exit 1
	fi
}

# build Go (for bootstrap)
function bootstrap {
	# if Go (for bootstrap) already exists,
	if [ -d "$INSTALLATION_DIR/go" ]; then
		# reuse it
		warn ">>> reusing go at: $INSTALLATION_DIR/go"

		ln -sf "$INSTALLATION_DIR/go" "$BOOTSTRAP_DIR"
	else
		arch=`uname -m`
		if [[ $arch == "aarch64" ]]; then
			error ">>> go 1.4 does not support $arch."

			warn ">>> installing go from the package manager..."

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
		warn ">>> uninstalling package manager's go..."

		# uninstall the package manager's golang
		sudo apt-get -y purge golang
		sudo apt-get -y autoremove
	else
		# remove bootstrap go
		warn ">>> cleaning go bootstrap at: $BOOTSTRAP_DIR"
		rm -rf "$BOOTSTRAP_DIR"
	fi
}

function clone_repo {
	warn ">>> cloning repository...(branch/tag: $INSTALL_BRANCH)"

	SRC_DIR="$TEMP_DIR/go-$INSTALL_BRANCH"

	# clone the repository
	rm -rf "$SRC_DIR" && \
		git clone -b "$INSTALL_BRANCH" "$REPOSITORY" "$SRC_DIR"
}

function build {
	warn ">>> building go with bootstrap go..."

	# build
	cd "$SRC_DIR/src" && \
		GOROOT_BOOTSTRAP=$BOOTSTRAP_DIR ./make.bash
	
	# delete unneeded files
	rm -rf "$SRC_DIR/.git" "$SRC_DIR/pkg/bootstrap" "$SRC_DIR/pkg/obj"
}

function install {
	warn ">>> installing..."

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
		info ">>> go with branch/tag: $INSTALL_BRANCH was installed at: $GO_DIR"
}

# for macOS
function install_go_macos {
	brew install go
}

# for linux
function install_go_linux {
	if [ -z $TERMUX_VERSION ]; then
		prep && bootstrap && install_go && clean_bootstrap
	else  # termux
		pkg install golang
	fi
}

case "$OSTYPE" in
	darwin*) install_go_macos ;;
	linux*) install_go_linux ;;
	*) error "* not supported yet: $OSTYPE" ;;
esac

