#!/usr/bin/env bash

# install_codelldb.sh
#
# Install vscode-lldb for neovim's DAP
#
# created on : 2022.07.20.
# last update: 2022.07.20.
#
# by meinside@duck.com


################################
#
# frequently updated values

# https://fennel-lang.org/setup#downloading-the-fennel-script
VERSION="1.6.10"	# XXX - edit for different version


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


INSTALLATION_PATH="$HOME/.local/codelldb"
TEMP_FILEPATH="/tmp/vscode-lldb.vsix"

# install
function install {
	os=$(uname -s | tr '[:upper:]' '[:lower:]')
	machine=$(uname -m)

	url="https://github.com/vadimcn/vscode-lldb/releases/download/v${VERSION}/codelldb-${machine}-${os}.vsix"

	rm -rf $INSTALLATION_PATH && \
		wget $url -O $TEMP_FILEPATH && \
		unzip $TEMP_FILEPATH -d "$INSTALLATION_PATH" && \
		rm -f $TEMP_FILEPATH &&
		info "codelldb was installed in $INSTALLATION_PATH"
}

case "$OSTYPE" in
	darwin*|linux*) install ;;
	*) error "* not supported yet: $OSTYPE" ;;
esac

