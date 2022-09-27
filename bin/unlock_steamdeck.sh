#!/usr/bin/env bash

# unlock_steamdeck.sh
#
# Unlocks steam deck's read-only file system.
#
# created on : 2022.09.27.
# last update: 2022.09.27.

sudo steamos-readonly disable && \
	sudo pacman-key --init && \
	sudo pacman-key --populate archlinux && \
	sudo pacman -Syu base-devel

