# scripts and tips for termux

## scripts

### install_proot_distro.sh

A script for installing proot-distro and printing help messages.

## guides and tips

### setup termux and other things

First things to do after installing termux:

```bash
$ pkg update
$ termux-setup-storage
```

### setup ubuntu on proot-distro

Install proot-distro,

```bash
$ pkg install proot-distro
```

install ubuntu linux,

```bash
$ proot-distro install ubuntu
```

login as root,

```bash
$ proot-distro login ubuntu
```

and install essential packages:

```bash
$ apt update
$ apt install sudo git zsh
# for building things
$ apt install build-essential cmake
```

#### add a user with separate home directory

Add a user and exit,

```bash
$ useradd -U -m -s `which zsh` USERNAME
$ echo "USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
$ exit
```

then you can login as the user with:

```bash
$ proot-distro login ubuntu --user USERNAME
```

#### add a user with shared home & tmp directory

Add a user and exit,

```bash
$ useradd -U -s `which zsh` USERNAME
$ exit
```

then you can login as the user with:

```bash
$ proot-distro login ubuntu --user USERNAME --termux-home --shared-tmp
```

#### mount host folders

```bash
$ proot-distro login ubuntu --user USERNAME --bind /storage/emulated/0/Download:/home/USERNAME/files
```

#### run sshd

```bash
# install sshd,
$ sudo apt install openssh-server

# edit config,
$ sudo vi /etc/ssh/sshd_config

# run service,
$ sudo service ssh start

# connect to the server,
$ ssh -p PORTNUMBER USERNAME@IP-ADDRESS
$ exit

# and stop service
$ sudo service ssh stop
```

### setup nerd fonts

Put [downloaded .ttf files](https://www.nerdfonts.com/font-downloads) into `~/.termux/` directory.

### setup things for development

Install [Termux:API from F-Droid](https://f-droid.org/packages/com.termux.api/), and install `termux-api`:

```bash
$ pkg install termux-api
```

Install [Termux:Widget from F-Droid](https://f-droid.org/en/packages/com.termux.widget), and create directories for scripts:

```bash
$ mkdir -p ~/.shortcuts/tasks
```

