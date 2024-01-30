# scripts for termux

## install_proot_distro.sh

A script for installing proot-distro and printing help messages.

## other guides

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

