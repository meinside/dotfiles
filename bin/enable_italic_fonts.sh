#!/usr/bin/env bash
#
# enable_italic_fonts.sh
#
# created on 2021.09.08.
# updated on 2021.09.08.

# colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

TERMINFO_FILE="/tmp/xterm-256color-italic"

cat <<EOF > $TERMINFO_FILE
xterm-256color-italic|xterm with 256 colors and italic,
  sitm=\E[3m, ritm=\E[23m,
  use=xterm-256color,

tmux|tmux terminal multiplexer,
  ritm=\E[23m, rmso=\E[27m, sitm=\E[3m, smso=\E[7m,
  use=xterm, use=screen,

tmux-256color|tmux with 256 colors,
  use=xterm-256color, use=tmux,
EOF

tic $TERMINFO_FILE
rm $TERMINFO_FILE

echo -e "${RED}>>> Set terminal type to 'xterm-256color-italic'${RESET}"

