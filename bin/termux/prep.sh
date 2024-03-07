#!/data/data/com.termux/files/usr/bin/env bash
#
# bin/termux/prep.sh
#
# for setting things up on termux and proot-distro
#
# (https://raw.githubusercontent.com/meinside/dotfiles/master/bin/termux/prep.sh)
# 
# last update: 2024.03.07.

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

# constants
PR_DISTRO="ubuntu"
PR_USERNAME="meinside"

# for running things on proot-distro as root
function root_run {
	proot-distro login $PR_DISTRO \
		--shared-tmp \
		-- $@
}

# [termux] setting things up
info ">>> setting things up for termux..."
info
termux-setup-stroage
pkg update
pkg install proot-distro

# [proot-distro] install distro
info ">>> installing proot-distro: $PR_DISTRO..."
info
proot-distro install $PR_DISTRO

# [proot-distro] install packages
info ">>> installing packages on proot-distro..."
info
root_run apt update
root_run apt install sudo git zsh build-essential cmake

# [proot-distro] add a sudoer user
info ">>> adding sudoer '$PR_USERNAME' to proot-distro..."
info
root_run useradd -U -m -s /usr/bin/zsh $PR_USERNAME
root_run sed -i "\$a$PR_USERNAME ALL=(ALL) NOPASSWD:ALL" /etc/sudoers

# [termux] create .custom_env
if [ ! -f ~/.custom_env ]; then
	bash -c "cat > ~/.custom_env" <<EOF
# .custom_env (termux)
#
# created on : $(date +%Y.%m.%d)
# last update: $(date +%Y.%m.%d)

# aliases for proot-distro
alias pdr="proot-distro login $PR_DISTRO"
alias pdu="proot-distro login $PR_DISTRO --user $PR_USERNAME --shared-tmp --bind /data/data/com.termux/files/home/storage/downloads:/home/$PR_USERNAME/files"

EOF

	info ">>> generated ~/.custom_env file for proot-distro aliases"
	info
fi

# [termux] create .shorcuts/ sample scripts
mkdir -p ~/.shortcuts/
if [ ! -f ~/.shortcuts/sample.sh ]; then
	bash -c "cat > ~/.shortcuts/sample.sh" << EOF
#!/data/data/com.termux/files/usr/bin/env bash
#
# .shortcuts/sample.sh
#
# sample script for termux widget's shortcuts
#
# created on : $(date +%Y.%m.%d)
# last update: $(date +%Y.%m.%d)

# functions for proot-distro
function root_run {
	proot-distro login $PR_DISTRO \
		--shared-tmp \
		-- $@
}
function user_run {
	proot-distro login $PR_DISTRO \
		--user $PR_USERNAME \
		--shared-tmp \
		--bind /data/data/com.termux/files/home/storage/downloads:/home/$PR_USERNAME/files \
		-- $@
}

# test
root_run echo "I am proot-distro \$(whoami)"
user_run echo "I am proot-distro \$(whoami)"

EOF

	chmod +x ~/.shortcuts/sample.sh

	info ">>> generated sample scripts in ~/.shortcuts/"
	info
fi

