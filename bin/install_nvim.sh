#!/usr/bin/env bash

# install_nvim.sh
# 
# for building neovim from source code
#
# last update: 2020.02.04.
# 
# by meinside@gmail.com

# * Update alternatives with:
#
# $ sudo update-alternatives --install /usr/bin/vi vi /usr/local/bin/nvim 60
# $ sudo update-alternatives --config vi
# $ sudo update-alternatives --install /usr/bin/vim vim /usr/local/bin/nvim 60
# $ sudo update-alternatives --config vim
# $ sudo update-alternatives --install /usr/bin/editor editor /usr/local/bin/nvim 60
# $ sudo update-alternatives --config editor

# XXX - for making newly created files/directories less restrictive
umask 0022

TMP_DIR=/tmp/nvim

NVIM_VERSION="v0.4.3"

function prep {
	# install needed packages
	sudo apt-get install -y libtool libtool-bin autoconf automake cmake g++ pkg-config unzip python-dev python3-pip gettext && \
		pip3 install --upgrade --user pynvim

	# symlink .vimrc file
	mkdir -p ~/.config/nvim && \
		ln -sf ~/.vimrc ~/.config/nvim/init.vim

	# clean tmp directory
	clean
}

function clean {
	sudo rm -rf $TMP_DIR
}

function install {
	git clone https://github.com/neovim/neovim.git $TMP_DIR && \
		cd $TMP_DIR && \
		git checkout $NVIM_VERSION

	# configure and build
	rm -rf build && \
		make clean && \
		make CMAKE_BUILD_TYPE=RelWithDebInfo

	# install
	sudo make install
}

# macOS
function install_macos {
	brew install neovim
}

# linux
function install_linux {
	prep && install && clean
}

case "$OSTYPE" in
	darwin*) install_macos ;;
	linux*) install_linux ;;
	*) echo "* Unsupported os type: $OSTYPE" ;;
esac

