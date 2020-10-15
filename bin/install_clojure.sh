#!/usr/bin/env bash

# install_clojure.sh
# 
# for downloading and setting up clojure with JDK
#
# (https://clojure.org/guides/getting_started#_installation_on_linux)
# 
# last update: 2020.10.15.
# 
# by meinside@gmail.com

# XXX - for making newly created files/directories less restrictive
umask 0022

# colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

CLOJURE_VERSION="1.10.1.708"	# XXX - change clojure version

# https://clojure.org/guides/getting_started#_installation_on_linux
CLOJURE_INSTALL_SCRIPT="https://download.clojure.org/install/linux-install-${CLOJURE_VERSION}.sh"
CLOJURE_BIN="/usr/local/bin/clojure"

LEIN_SRC="https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein"
LEIN_BIN="/usr/local/bin/lein"

JDK_DIR=/opt/jdk

# (for ARM devices)
#
# ARM32 HF: https://www.azul.com/downloads/zulu-community/?architecture=arm-32-bit-hf&package=jdk
# ARM64   : https://www.azul.com/downloads/zulu-community/?architecture=arm-64-bit&package=jdk
PLATFORM=`uname -m`
case "$PLATFORM" in
	arm64|aarch64) ZULU_EMBEDDED_VERSION="zulu11.41.75-ca-jdk11.0.8-linux_aarch64" ;;
	armv7*) ZULU_EMBEDDED_VERSION="zulu11.41.75-ca-jdk11.0.8-linux_aarch32hf" ;;
	x86*) ZULU_EMBEDDED_VERSION="" ;;
	*) echo "* Unsupported platform: $PLATFORM"; exit 1 ;;
esac
ZULU_EMBEDDED_TGZ="http://cdn.azul.com/zulu-embedded/bin/${ZULU_EMBEDDED_VERSION}.tar.gz"

function install_zulu_jdk {
	if [ -x  "${JDK_DIR}/${ZULU_EMBEDDED_VERSION}/bin/javac" ]; then
		echo -e "${YELLOW}>>> JDK already installed at: ${JDK_DIR}/${ZULU_EMBEDDED_VERSION}${RESET}"
		return 0
	fi

	# install zulue-embedded java
	sudo mkdir -p "$JDK_DIR" && \
		cd "$JDK_DIR" && \
		sudo wget "$ZULU_EMBEDDED_TGZ" && \
		sudo tar -xzvf "${ZULU_EMBEDDED_VERSION}.tar.gz" && \
		sudo update-alternatives --install /usr/bin/java java ${JDK_DIR}/${ZULU_EMBEDDED_VERSION}/bin/java 181 && \
		sudo update-alternatives --install /usr/bin/javac javac ${JDK_DIR}/${ZULU_EMBEDDED_VERSION}/bin/javac 181 && \
		echo -e "${GREEN}>>> Installed JDK at: ${JDK_DIR}/${ZULU_EMBEDDED_VERSION}${RESET}"
}

function install_openjdk {
	sudo apt-get -y install openjdk-8-jdk
}

function prep {
	case "$PLATFORM" in
		arm*|aarch*) install_zulu_jdk ;;
		*) install_openjdk ;;
	esac
}

function install_clojure {
	if [ -x "${CLOJURE_BIN}" ]; then
		echo -e "${YELLOW}>>> clojure already installed at: ${CLOJURE_BIN}${RESET}"
		return 0
	fi

	sudo apt-get -y install rlwrap && \
		wget -O - ${CLOJURE_INSTALL_SCRIPT} | sudo bash && \
		echo -e "${GREEN}>>> ${CLOJURE_BIN} was installed.${RESET}"
}

function install_leiningen {
	if [ -x "${LEIN_BIN}" ]; then
		echo -e "${YELLOW}>>> leiningen already installed at: ${LEIN_BIN}${RESET}"
		return 0
	fi

	# install leiningen
	sudo wget "$LEIN_SRC" -O "$LEIN_BIN" && \
		sudo chown $USER.$USER "$LEIN_BIN" && \
		sudo chmod uog+x "$LEIN_BIN" && \
		echo -e "${GREEN}>>> ${LEIN_BIN} was installed.${RESET}"
}

function clean {
	sudo rm -f "${JDK_DIR}/${ZULU_EMBEDDED_TGZ}.tar.gz"
}

function install_linux {
	prep && install_clojure && install_leiningen && clean
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
	*) echo "* Unsupported os type: $OSTYPE" ;;
esac

