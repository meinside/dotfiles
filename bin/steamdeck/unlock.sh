#!/usr/bin/env bash

# bin/steamdeck/unlock.sh
#
# Unlocks steam deck's read-only file system.
#
# created on : 2022.09.27.
# last update: 2022.09.28.

sudo steamos-readonly disable && \
	sudo pacman-key --init && \
	sudo pacman-key --populate archlinux && \
	sudo pacman -Syu base-devel && \
	sudo pacman -S glibc linux-api-headers

