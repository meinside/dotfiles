# scripts and tips for termux

In termux, download [bin/termux/prep.sh](https://raw.githubusercontent.com/meinside/dotfiles/master/bin/termux/prep.sh),

edit constants `PR_DISTRO` and `PR_USERNAME`,

and run it with bash to setup termux + proot-distro.

Or do things manually with following guides and tips:

## guides and tips

### setup termux and other things

First things to do after installing termux:

```bash
$ pkg update
$ termux-setup-storage
```

### setup ubuntu on proot-distro

In termux, install proot-distro,

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

and install essential packages in proot-distro:

```bash
$ apt update
$ apt install sudo git zsh
# for building things
$ apt install build-essential cmake
```

#### add a user with separate home directory

In proot-distro, add a sudoer and exit,

```bash
$ useradd -U -m -s `which zsh` USERNAME
$ echo "USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
$ exit
```

then in termux, you can login as the sudoer with:

```bash
$ proot-distro login ubuntu --user USERNAME
```

#### add a user with shared home & tmp directory

In proot-distro, add a user and exit,

```bash
$ useradd -U -s `which zsh` USERNAME
$ exit
```

then in termux, you can login as the user with:

```bash
$ proot-distro login ubuntu --user USERNAME --termux-home --shared-tmp
```

#### mount host folders

In termux,

```bash
$ proot-distro login ubuntu --user USERNAME --bind /storage/emulated/0/Download:/home/USERNAME/files
```

#### run sshd

In proot-distro,

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

Install [Termux:Styling from F-Droid](https://f-droid.org/en/packages/com.termux.styling/) and select appropriate font from the settings.

### setup things for development

#### Termux:API

Install [Termux:API from F-Droid](https://f-droid.org/packages/com.termux.api/), and install `termux-api`:

```bash
$ pkg install termux-api
```

API documents can be found [here](https://wiki.termux.com/wiki/Termux:API).

#### Termux:Widget

Install [Termux:Widget from F-Droid](https://f-droid.org/en/packages/com.termux.widget), and create directories for scripts:

```bash
$ mkdir -p ~/.shortcuts/tasks ~/.shortcuts/icons
```

Bash scripts should start with the following line:

```bash
#!/data/data/com.termux/files/usr/bin/env bash
```

