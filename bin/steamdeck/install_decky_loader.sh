#!/usr/bin/env bash

# bin/steamdeck/install_decky_loader.sh
#
# Install [Decky Loader](https://github.com/SteamDeckHomebrew/decky-loader).
#
# created on : 2023.01.11.
# last update: 2023.07.05.

if [[ $1 == "--uninstall" ]]; then
	# uninstall
	curl -L https://github.com/SteamDeckHomebrew/decky-loader/raw/main/dist/uninstall.sh | sh
else
	# install
	curl -L https://github.com/SteamDeckHomebrew/decky-loader/raw/main/dist/install_release.sh | sh
fi

