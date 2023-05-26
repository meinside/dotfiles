#!/usr/bin/env bash

# bin/steamdeck/install_tailscale.sh
#
# Install or update tailscale on steam deck.
#
# (referenced [this guide](https://gist.github.com/legowerewolf/1b1670457cfac9201ee9d67840952147))
#
# NOTE: If there's an error: 'Partition /usr is mounted read only',
# NOTE: do `sudo systemd-sysext unmerge`
# NOTE: try something again, and
# NOTE: do `sudo systemd-sysext merge` back.
#
# created on : 2023.05.26.
# last update: 2023.05.26.


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


TAILSCALED_SERVICE_FILE="/etc/systemd/system/tailscaled.service"

# (1) create `tailscaled.service` file
# https://gist.github.com/legowerewolf/1b1670457cfac9201ee9d67840952147#file-tailscaled-service
	sudo bash -c "cat > $TAILSCALED_SERVICE_FILE" <<EOF
[Unit]
Description=Tailscaled
Documentation=https://gist.github.com/legowerewolf/1b1670457cfac9201ee9d67840952147
Wants=network-pre.target
After=network-pre.target NetworkManager.service systemd-resolved.service

[Service]
ExtensionDirectories=/var/lib/extensions/tailscale

ExecStartPre=/usr/sbin/tailscaled --cleanup
ExecStart=/usr/sbin/tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/run/tailscale/tailscaled.sock
ExecStopPost=/usr/sbin/tailscaled --cleanup

Restart=on-failure

RuntimeDirectory=tailscale
RuntimeDirectoryMode=0755
StateDirectory=tailscale
StateDirectoryMode=0700
CacheDirectory=tailscale
CacheDirectoryMode=0750
Type=notify

[Install]
WantedBy=multi-user.target
EOF

# (2) configure and run things
# https://gist.github.com/legowerewolf/1b1670457cfac9201ee9d67840952147#file-tailscale-sh
# make system configuration vars available
source /etc/os-release

# set invocation settings for this script:
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error when substituting.
# -o pipefail: the return value of a pipeline is the status of the last command to exit with a non-zero status, or zero if no command exited with a non-zero status
set -eu -o pipefail

# save the current directory silently
pushd . > /dev/null

# make a temporary directory, save the name, and move into it
dir="$(mktemp -d)"
cd "${dir}"

echo -n "Installing Tailscale: Getting version..."

# get info for the latest version of Tailscale
tarball="$(curl -s 'https://pkgs.tailscale.com/stable/?mode=json' | jq -r .Tarballs.amd64)"
version="$(echo "${tarball}" | cut -d_ -f2)"

echo -n "got ${version}. Downloading..."

# download the Tailscale package itself
curl -s "https://pkgs.tailscale.com/stable/${tarball}" -o tailscale.tgz

echo -n "done. Installing..."

# extract the tailscale binaries
tar xzf tailscale.tgz
tar_dir="$(echo "${tarball}" | cut -d. -f1-3)"
test -d "$tar_dir"

# create our target directory structure
mkdir -p tailscale/usr/{bin,sbin,lib/{systemd/system,extension-release.d}}

# pull things into the right place in the target dir structure
cp -rf "$tar_dir/tailscale" tailscale/usr/bin/tailscale
cp -rf "$tar_dir/tailscaled" tailscale/usr/sbin/tailscaled

# write a systemd extension-release file
echo -e "SYSEXT_LEVEL=1.0\nID=steamos\nVERSION_ID=${VERSION_ID}" >> tailscale/usr/lib/extension-release.d/extension-release.tailscale

# create the system extension folder if it doesn't already exist, remove the old version of our tailscale extension, and install our new one
sudo mkdir -p /var/lib/extensions
sudo rm -rf /var/lib/extensions/tailscale
sudo cp -rf tailscale /var/lib/extensions/

# return to our original directory (silently) and clean up
popd > /dev/null
sudo rm -rf "${dir}"

sudo systemd-sysext refresh > /dev/null 2>&1
sudo systemctl daemon-reload > /dev/null

sudo systemctl enable systemd-sysext --now

info "done."

info "For logging in: $ sudo tailscale up --qr --operator=steamdeck"

info "For making it autostart: $ sudo systemctl enable tailscaled --now"
#sudo systemctl enable tailscaled --now

info "For start/restarting it now: $ sudo systemctl restart tailscaled"
#sudo systemctl restart tailscaled

