#!/usr/bin/env bash

# install_clojure.sh
# 
# for downloading and setting up clojure with JDK
#
# (https://clojure.org/guides/getting_started#_installation_on_linux)
# 
# last update: 2022.04.06.
# 
# by meinside@gmail.com


################################
#
# frequently updated values

CLOJURE_VERSION="1.11.1.1105"	# XXX - change clojure version if needed


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

# https://clojure.org/guides/getting_started#_installation_on_linux
CLOJURE_INSTALL_SCRIPT="https://download.clojure.org/install/linux-install-${CLOJURE_VERSION}.sh"
CLOJURE_BIN="/usr/local/bin/clojure"

LEIN_SRC="https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein"
LEIN_BIN="/usr/local/bin/lein"

JDK_DIR=/opt/jdk

# JDK LTS (for ARM devices)
#
# ARM32 HF: https://www.azul.com/downloads/zulu-community/?architecture=arm-32-bit-hf&package=jdk
# ARM64   : https://www.azul.com/downloads/zulu-community/?architecture=arm-64-bit&package=jdk
PLATFORM=`uname -m`
case "$PLATFORM" in
	arm64|aarch64) ZULU_VERSION="zulu17.32.13-ca-jdk17.0.2-linux_aarch64" ;;
	armv7*) ZULU_VERSION="zulu17.32.13-ca-jdk17.0.2-linux_aarch32hf" ;;
	x86*) ZULU_VERSION="" ;;
	*) error "* unsupported platform: $PLATFORM"; exit 1 ;;
esac
ZULU_TGZ="https://cdn.azul.com/zulu/bin/${ZULU_VERSION}.tar.gz"

function install_zulu_jdk {
	if [ -x  "${JDK_DIR}/${ZULU_VERSION}/bin/javac" ]; then
		warn ">>> JDK already installed at: ${JDK_DIR}/${ZULU_VERSION}"
		return 0
	fi

	# install zulu-jdk
	sudo mkdir -p "$JDK_DIR" && \
		cd "$JDK_DIR" && \
		sudo wget "$ZULU_TGZ" && \
		sudo tar -xzvf "${ZULU_VERSION}.tar.gz" && \
		sudo update-alternatives --install /usr/bin/java java ${JDK_DIR}/${ZULU_VERSION}/bin/java 181 && \
		sudo update-alternatives --install /usr/bin/javac javac ${JDK_DIR}/${ZULU_VERSION}/bin/javac 181 && \
		info ">>> installed JDK at: ${JDK_DIR}/${ZULU_VERSION}"
}

function install_openjdk {
	sudo apt-get -y install openjdk-17-jdk
}

function prep {
	case "$PLATFORM" in
		arm*|aarch*) install_zulu_jdk ;;
		*) install_openjdk ;;
	esac
}

function install_clojure {
	if [ -x "${CLOJURE_BIN}" ]; then
		warn ">>> clojure already installed at: ${CLOJURE_BIN}"
		return 0
	fi

	sudo apt-get -y install rlwrap && \
		wget -O - ${CLOJURE_INSTALL_SCRIPT} | sudo bash && \
		info ">>> ${CLOJURE_BIN} was installed."
}

function install_leiningen {
	if [ -x "${LEIN_BIN}" ]; then
		warn ">>> leiningen already installed at: ${LEIN_BIN}"
		return 0
	fi

	# install leiningen
	sudo wget "$LEIN_SRC" -O "$LEIN_BIN" && \
		sudo chown $USER.$USER "$LEIN_BIN" && \
		sudo chmod uog+x "$LEIN_BIN" && \
		info ">>> ${LEIN_BIN} was installed."
}

function clean {
	sudo rm -f "${JDK_DIR}/${ZULU_VERSION}.tar.gz"
}

function install_linux {
	if [ -z $TERMUX_VERSION ]; then
		prep && install_clojure && install_leiningen && clean
	else  # termux
		error "* termux not supported yet."
	fi
}

function install_macos {
	brew install leiningen \
		borkdude/brew/clj-kondo \
		candid82/brew/joker \
		clojure
}

case "$OSTYPE" in
	darwin*) install_macos ;;
	linux*) install_linux ;;
	*) error "* not supported yet: $OSTYPE" ;;
esac

