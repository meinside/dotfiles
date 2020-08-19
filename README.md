# My dot/config files for macOS, Linux, Raspberry Pi, or WSL

by Sungjin Han <meinside@gmail.com>

## Description

My personal dot/config files for:

- macOS (**Catalina**)
- Raspberry Pi (**Raspbian Buster**)
- Linux (**Debian/Ubuntu**)
- WSL 2 (**Windows 10**)

---

## 0. Easy install

### A. Use prep scripts

Prep scripts will clone dot/config files from the repository and install several things automatically.

#### a. On Linux / Raspberry Pi / WSL

```bash
$ cd ~
$ wget -O - "https://raw.githubusercontent.com/meinside/dotfiles/master/bin/prep.sh" | bash
```

It will also install some useful packages.

#### b. On macOS

```bash
$ cd ~
$ wget -O - "https://raw.githubusercontent.com/meinside/dotfiles/master/bin/prep_macos.sh" | bash
```

It will also install **Homebrew**.

---

## 1. Tips for macOS

### A. Setup paths

Reorder paths in **/etc/paths** for convenience:

``$ sudo vi /etc/paths``

=> put **/usr/local/bin** on the top for Homebrew

```
/usr/local/bin
/usr/bin
/bin
/usr/sbin
/sbin
```

### B. How to remove unused Xcode simulators

```bash
$ xcrun simctl delete unavailable
```

---

## 2. Tips for Raspberry Pi

### A. Useful Configurations

#### a. Setting up watchdog

```bash
$ sudo modprobe bcm2708_wdog
$ sudo vi /etc/modules
```

then add following line:

```
bcm2708_wdog
```

Install watchdog and edit conf:

```bash
$ sudo apt-get install watchdog
$ sudo vi /etc/watchdog.conf
```

uncomment following line:

```
watchdog-device = /dev/watchdog
```

and restart the service:

```bash
$ sudo systemctl restart watchdog
```

#### b. Setting up i2c

```bash
$ sudo modprobe i2c_dev
$ sudo vi /etc/modules
```

uncomment following line:

```
i2c-dev
```

edit blacklist:

```bash
$ sudo vi /etc/modprobe.d/raspi-blacklist.conf
```

and comment out following lines if exist:

```
blacklist spi-bcm2708
blacklist i2c-bcm2708
```

Then do the following:

```bash
$ sudo apt-get install i2c-tools
$ sudo usermod -a -G i2c USERNAME
```

### B. Additional Configurations

#### a. WiFi Configuration

##### i. Add a file on the sdcard and reboot

Create a file named `wpa_supplicant.conf` with following content:

```
country=JP
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
        ssid="YOUR-SSID"
        psk=YOUR-PSK

        # Protocol type can be: RSN (for WP2) and WPA (for WPA1)
        proto=RSN

        # Key management type can be: WPA-PSK or WPA-EAP (Pre-Shared or Enterprise)
        key_mgmt=WPA-PSK

        # Pairwise can be CCMP or TKIP (for WPA2 or WPA1)
        pairwise=CCMP

        # Authorization option should be OPEN for both WPA1/WPA2 (in less commonly used are SHARED and LEAP)
        auth_alg=OPEN

        # SSID scan technique (0 for broadcast, 1 for hidden)
        scan_ssid=1

        # Priority
        priority=1
}
```

Replace `YOUR-SSID` and `YOUR-PSK` to yours.

`YOUR-PSK` can be generated like this:

```bash
$ wpa_passphrase [SSID] [PASSWORD]
```

For example,

```bash
$ wpa_passphrase my_ssid 0123456789abc
```

Now put the file on the root of your **Raspberry-Pi-ready** sdcard and boot with it.

##### ii. Edit conf file

Do the same on file: `/etc/wpa_supplicant/wpa_supplicant.conf`.

```bash
$ sudo vi /etc/wpa_supplicant/wpa_supplicant.conf
```

After that, turn the WLAN device off and on:

```bash
$ sudo ifdown wlan0
$ sudo ifup wlan0
```

Your WLAN device's name may be different from 'wlan0'.

You can list yours with following command:

```bash
$ ls /sys/class/net | grep wl
```

#### b. UTF-8 configuration for MySQL

Open conf:

```bash
$ sudo vi /etc/mysql/my.cnf
```

and add following lines:

```
[mysql]
default-character-set = utf8
 
[client]
default-character-set = utf8
 
[mysqld]
character-set-client-handshake=FALSE
init_connect="SET collation_connection = utf8_general_ci"
init_connect="SET NAMES utf8"
character-set-server = utf8
collation-server = utf8_general_ci
 
[mysqldump]
default-character-set = utf8
```

#### c. AFP & Zero-conf DNS configuration

##### i. Install netatalk and avahi-daemon

```bash
$ sudo apt-get install netatalk
$ sudo apt-get install avahi-daemon
```

##### ii. Add an avahi-daemon service

Create a service file:

```bash
$ sudo vi /etc/avahi/services/SERVICE_NAME.service
```

and add following lines:

```
<?xml version="1.0" standalone='no'?><!--*-nxml-*-->
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
    <name replace-wildcards="yes">%h</name>
    <service>
        <type>_afpovertcp._tcp</type>
        <port>548</port>
    </service>
    <service>
        <type>_http._tcp</type>
        <port>80</port>
    </service>
    <service>
        <type>_ssh._tcp</type>
        <port>22</port>
    </service>
    <service>
        <type>_device-info._tcp</type>
        <port>0</port>
        <txt-record>model=Xserve</txt-record>
    </service>
</service-group>
```

### C. Etc. Tips

#### a. Set static dns server even when using DHCP

Open conf:

```bash
$ sudo vi /etc/dhcp/dhclient.conf
```

and add following line:

```
supersede domain-name-servers 8.8.8.8, 8.8.4.4;
```

#### b. Using bluetooth

##### 1. With on-board bluetooth module

###### i. Install required packages

Install pi-bluetooth:

```bash
$ sudo apt-get install pi-bluetooth
```

and reboot.

###### ii. Use bluetoothctl

After reboot, use ``bluetoothctl`` for turning up, scanning, and connecting.

```bash
$ sudo bluetoothctl
```

Type ``help`` for commands and options.

##### 2. With dongle

* referenced: http://wiki.debian.org/BluetoothUser

###### i. Make Raspberry Pi discoverable by other bluetooth devices

```bash
$ sudo hciconfig hci0 piscan
$ sudo bluetooth-agent 0000
```

Do as the screen says, and make Raspberry Pi hidden from other bluetooth devices again:

```bash
$ sudo hciconfig hci0 noscan
```

###### ii. Display bluetooth device (for checking proper installation)

```bash
$ hcitool dev
```

###### iii. Scan nearby bluetooth devices

```bash
$ hcitool scan
```

###### iv. Settings

Open conf:

```bash
$ sudo vi /etc/default/bluetooth
```

and add/alter following lines:

```
# edit
#HID2HCI_ENABLED=0
HID2HCI_ENABLED=1

# add static device information
device 01:23:45:AB:CD:EF {
    name "Bluetooth Device Name";
    auth enable;
    encrypt enable;
}
```

#### c. Use logrotate.d

Create a file:

```bash
$ sudo vi /etc/logrotate.d/some_file
```

and add following lines:

```
  /some_where/*.log {
    compress
    copytruncate
    daily
    delaycompress
    missingok
    rotate 7
    size=5M
  }
```

#### d. Mount external hdd/ssd on boot time

Open fstab:

```bash
$ sudo vi /etc/fstab
```

and add following lines:

```
/dev/some_hdd1  /some/where/to/mount1  ext4  defaults   0 0
/dev/some_hdd2  /some/where/to/mount2  vfat  rw,noatime,uid=7777,gid=7778,user   0 0
```

**uid** and **gid** can be retrieved with command 'id'.

#### e. Run scripts periodically

```bash
$ crontab -e
```

and add following lines:

```
# every 5 minutes
*/1 * * * * bash -l /some/script_that_needs_login.sh
# every 1 hour
0 1 * * * bash -l -c /some/ruby_script_under_rvm.rb
```

#### f. Block IPs temporarily with iptables

```bash
$ sudo iptables -A INPUT -s 999.999.999.999 -j DROP
```

### Z. Troubleshooting

#### a. Error message: 'smsc95xx 1-1.1:1.0: eth0: kevent 2 may have been dropped'

Append ``smsc95xx.turbo_mode=N`` to ``/boot/cmdline.txt`` file, and

add/alter following lines in ``/etc/sysctl.conf``:

```
#vm.vfs_cache_pressure = 100
vm.vfs_cache_pressure = 300
#vm.min_free_kbytes=8192
vm.min_free_kbytes=32768
```

---

## 3. Tips for Linux

### A. Make a swap file

```bash
$ sudo dd if=/dev/zero of=/swapfile bs=1024 count=1M
$ sudo chmod 0600 /swapfile
$ sudo mkswap /swapfile
```

and append following line to `/etc/fstab`:

```
/swapfile swap swap defaults 0 0
```

### B. Install essential packages

```bash
$ sudo apt-get install zsh tmux fail2ban nginx
```

### C. Configure locale and timezone

```bash
$ sudo apt-get install locales tzdata
$ sudo locale-gen en_US.UTF-8
$ sudo locale-gen ko_KR.UTF-8
$ sudo dpkg-reconfigure tzdata
```


---

## 4. Tips for WSL

### A. Prerequisite: Install Chocolatey and WSL

#### 1. Install Chocolatey

As [this installation guide](https://chocolatey.org/docs/installation) says, run **PowerShell** as administrator, and type following things:

```
Shell> Set-ExecutionPolicy AllSigned
Shell> Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
```

#### 2. Install WSL

Install `WSL` on `Windows 10` with [this guide](https://docs.microsoft.com/en-us/windows/wsl/install-win10).

### B. Install Terminal Emulator for WSL

[Windows Terminal](https://www.microsoft.com/en-us/p/windows-terminal/9n0dx20hk701) is recommended.

#### 1. Change starting directory for WSL

Open Windows Terminal's settings(settings.json), and add following to your WSL profile:

```
// e.g.
{
  "guid": "{07b52e3e-de2c-5db4-bd2d-ba144ed6c273}",
  "hidden": false,
  "name": "Ubuntu-20.04",
  "source": "Windows.Terminal.Wsl",

  // starting directory
  "startingDirectory": "//wsl$/Ubuntu-20.04/home/MY_ACCOUNT"
}
```

### Z. Trouble Shooting

#### 1. `Hash Sum Mismatch` on apt-get update

```bash
$ sudo rm -rf /var/lib/apt/lists/partial
$ sudo apt-get update -o Acquire::CompressionTypes::Order::=gz
```

#### 2. `cannot allocate memory` when forking a new process

Try appending the following line to `/etc/sysctl.conf` file:

```bash
vm.overcommit_memory = 2
```

---

