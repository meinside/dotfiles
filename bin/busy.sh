#!/usr/bin/env bash

# bin/busy.sh
#
# make the machine busy for some seconds
#
# (referenced: https://www.reddit.com/r/oraclecloud/comments/yxlbxn/a_script_to_keep_always_free_instances_from_auto/)
#
# for cronjob: 0 3 * * * ~/bin/busy.sh
#
# last update: 2023.03.08.

# generate CPU spikes for 30 seconds
SECS=30
/usr/bin/timeout "${SECS}s" /usr/bin/sha1sum /dev/zero

# generate network traffic (https://ubuntu.com/download/server)
FILE_URL="https://releases.ubuntu.com/22.04.2/ubuntu-22.04.2-live-server-amd64.iso"
/usr/bin/wget -qO- $FILE_URL &> /dev/null

