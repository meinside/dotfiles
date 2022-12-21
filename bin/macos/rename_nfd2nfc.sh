#!/usr/bin/env sh
#
# bin/macos/rename_nfd2nfc.sh
#
# rename all files in the given directory (from NFD to NFC)
#
# * install `convmv` with:
#
#   $ brew install convmv
#
# last update: 2022.12.21.

if [ $# -ge 1 ]; then
	convmv -r -f utf8 -t utf8 --nfc --notest "$1"
else
	echo "Usage: $0 [directory_name]"
fi
