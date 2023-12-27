# Tips

## 1. For macOS

### A. Useful Scripts

#### a. Hack things

Have a look at this script: [`bin/macos/hack.sh`](https://github.com/meinside/dotfiles/blob/master/bin/macos/hack.sh).

```bash
$ bin/macos/hack.sh
```

#### b. How to remove unused Xcode simulators

For removing unused iOS simulators from Xcode:

```bash
$ xcrun simctl delete unavailable
```

#### c. Forward video/audio from Android devices

Firstly, enable USB debugging in the developer menu in the Android device.

Install [scrcpy](https://github.com/Genymobile/scrcpy) with:

```bash
$ brew install scrcpy
$ brew brew install android-platform-tools
```

##### (i) How to connect

[Here](https://github.com/Genymobile/scrcpy/blob/master/doc/connection.md) is the guide.

Connect the Android device to macOS with USB cable, and get its IP address with:

```bash
$ adb shell ip route
```

enable `adb` over TCP/IP with:

```bash
$ adb tcpip 5555
```

disconnect the USB cable, and connect it over TCP/IP with:

```bash
$ adb connect YOUR_DEVICE_IP:5555
```

##### (ii) Run scrcpy

```bash
$ scrcpy --tcpip=YOUR_DEVICE_IP:5555
```

For forwarding audio only:

```bash
$ scrcpy --tcpip=YOUR_DEVICE_IP:5555 --no-video --audio-buffer=400 --audio-bit-rate=320K --turn-screen-off
```

---

## 2. For Raspberry Pi

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

##### (i) Add a file on the sdcard and reboot

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

##### (ii) Edit conf file

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

#### b. AFP & Zero-conf DNS configuration

##### (i) Install netatalk and avahi-daemon

```bash
$ sudo apt-get install netatalk
$ sudo apt-get install avahi-daemon
```

##### (ii) Add an avahi-daemon service

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

#### c. Increase performance/lifespan of storage

Try mounting frequently-written directories (including /tmp) to tmpfs.

For example, this is a part of my `/etc/fstab` file:

```
# tmpfs (https://wiki.archlinux.org/title/tmpfs)
tmpfs    /tmp    tmpfs    defaults,noatime,nosuid,size=1536m    0 0
tmpfs    /var/log    tmpfs    defaults,noatime,nosuid,mode=0755,size=128m    0 0
```

See [this article](https://haydenjames.io/increase-performance-lifespan-ssds-sd-cards/).

#### d. Enable TRIM on an external SSD

If the SSD [supports TRIM](https://www.jeffgeerling.com/blog/2020/enabling-trim-on-external-ssd-on-raspberry-pi),

##### (i) Add a udev rule

Create `/etc/udev/rules.d/10-trim.rules` file with the following line:

```
ACTION=="add|change", ATTRS{idVendor}=="XXXX", ATTRS{idProduct}=="YYYY", SUBSYSTEM=="scsi_disk", ATTR{provisioning_mode}="unmap"
```

where **XXXX** is the vendor id and **YYYY** is the product id

which can be retrieved from `lsusb` command:

```
Bus 002 Device 002: ID XXXX:YYYY My Lovely SSD
Bus 002 Device 001: ID 1d6b:0003 Linux Foundation 3.0 root hub
Bus 001 Device 002: ID 2109:3431 VIA Labs, Inc. Hub
Bus 001 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
```

##### (ii) Enable a timer

For running `fstrim` automatically, enable a timer with:

```bash
$ sudo systemctl enable fstrim.timer
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

##### (i) With on-board bluetooth module

###### 1. Install required packages

Install pi-bluetooth:

```bash
$ sudo apt-get install pi-bluetooth
```

and reboot.

###### 2. Use bluetoothctl

After reboot, use ``bluetoothctl`` for turning up, scanning, and connecting.

```bash
$ sudo bluetoothctl
```

Type ``help`` for commands and options.

##### (ii) With dongle

* referenced: http://wiki.debian.org/BluetoothUser

###### 1. Make Raspberry Pi discoverable by other bluetooth devices

```bash
$ sudo hciconfig hci0 piscan
$ sudo bluetooth-agent 0000
```

Do as the screen says, and make Raspberry Pi hidden from other bluetooth devices again:

```bash
$ sudo hciconfig hci0 noscan
```

###### 2. Display bluetooth device (for checking proper installation)

```bash
$ hcitool dev
```

###### 3. Scan nearby bluetooth devices

```bash
$ hcitool scan
```

###### 4. Settings

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

### Z. Trouble Shooting

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

## 3. For Linux

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

### B. Configure locale and timezone

```bash
$ sudo apt-get install locales tzdata
$ sudo locale-gen en_US.UTF-8
$ sudo locale-gen ko_KR.UTF-8
$ sudo dpkg-reconfigure tzdata
```

---

## 4. For WSL

### A. Install WSL

Install `WSL` on `Windows 11` with [this guide](https://docs.microsoft.com/en-us/windows/wsl/install).

### B. Terminal Emulator for WSL

[Windows Terminal](https://www.microsoft.com/store/productId/9N0DX20HK701) is recommended.

#### 1. Change starting directory for WSL

Open Windows Terminal's settings and change 'Starting Directory' to: `\\wsl$\LINUX-DISTRO\home\USERNAME`

where *LINUX-DISTRO* is your Linux distro's name (eg. Ubuntu), and *USERNAME* is your linux username.

### C. Package Manager

Use `winget`: [Windows Package Manager](https://www.microsoft.com/store/productId/9NBLGGH4NNS1).

```bash
# eg.
$ winget search tailscale
$ winget install tailscale
$ winget upgrade --all
```

### Z. Trouble Shooting

-

---

## 999. Other Tips

### A. Server Configurations

#### a. UTF-8 configuration for MySQL

Open conf:

```bash
$ sudo vi /etc/mysql/my.cnf
```

and add following lines:

```
[mysql]
default-character-set = utf8mb4

[client]
default-character-set = utf8mb4

[mysqld]
character-set-client-handshake=FALSE
init_connect="SET collation_connection = utf8mb4_unicode_ci
init_connect="SET NAMES utf8mb4"
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[mysqldump]
default-character-set = utf8mb4
```

---

