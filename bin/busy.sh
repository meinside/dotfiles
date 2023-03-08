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

SECS=30

/usr/bin/timeout "${SECS}s" /usr/bin/sha1sum /dev/zero

