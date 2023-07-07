# Thins to do before using Steam Deck

- [ ] Settings - System - Enable Developer Mode
- [ ] Settings - Developer - Enable CEF Remote Debugging
- [ ] (now switch to the desktop mode)
- [ ] Open 'Konsole'
- [ ] Set your password with `passwd`
- [ ] Run `wget -O - "https://raw.githubusercontent.com/meinside/dotfiles/master/bin/prep.sh" | bash`
  * If `prep.sh` fails due to pre-existing `.config` directory,
  * run `git restore .config` and remove the temporary directory 'configs.tmp'
- [ ] Unlock the Steam Deck by running `bin/steamdeck/unlock.sh`
- [ ] Install decky loader with `bin/steamdeck/install_decky_loader.sh`

# For Xbox Game Pass

- [ ] (switch to the desktop mode)
- [ ] Install 'Microsoft Edge' from 'Discover'
- [ ] Right-click on the 'Microsoft Edge' and select 'Add to Steam'
- [ ] Open 'Konsole'
- [ ] Run `flatpak --user override --filesystem=/run/udev:ro com.microsoft.Edge`
- [ ] Launch 'Steam'
- [ ] Open 'Properties' by right-clicking on 'Microsoft Edge' in the 'Library'
- [ ] Change its name to 'Xbox Cloud Gaming (Beta)'
- [ ] Append ` --window-size=1024,640 --force-device-scale-factor=1.25 --device-scale-factor=1.25 --kiosk "https://www.xbox.com/ko-KR/play"` at the end of the command line of 'Launch Options'
- [ ] Right-click and get into 'Management' - 'Controller Layout' screen
- [ ] Search for community controller templates, apply one, and finished.

# NOTES

* Mouse Left-click = Steam Button + Right Trigger
* Mouse Right-click = Steam Button + Left Trigger

