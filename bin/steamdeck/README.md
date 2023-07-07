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

