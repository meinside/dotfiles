# Things to do before using Steam Deck

- [ ] Settings - System - Enable Developer Mode
- [ ] Settings - Developer - Enable CEF Remote Debugging
- [ ] (now switch to the desktop mode)
- [ ] Open 'Konsole',
- [ ] Set your password with `passwd`,
- [ ] ~~Unlock the Steam Deck by running `bin/steamdeck/unlock.sh`,~~ No need to unlock anymore; use [distrobox](https://github.com/89luca89/distrobox):
  * Create a container with: `distrobox create -n ubuntu -i ubuntu:22.04 --additional-packages "git" --init-hooks "wget -O - 'https://raw.githubusercontent.com/meinside/dotfiles/master/bin/prep.sh' | bash"`
  * then enter the container with: `distrobox enter ubuntu`
- [ ] And install [Decky Loader](https://github.com/SteamDeckHomebrew/decky-loader) by downloading and running the [installer](https://github.com/SteamDeckHomebrew/decky-installer/releases/latest/download/decky_installer.desktop).

# Setup Xbox Game Pass with Microsoft Edge

- [ ] (switch to the desktop mode)
- [ ] Install 'Microsoft Edge' from 'Discover'
- [ ] Right-click on the 'Microsoft Edge' and select 'Add to Steam'
- [ ] Open 'Konsole', and
- [ ] Run `flatpak --user override --filesystem=/run/udev:ro com.microsoft.Edge`
- [ ] Launch 'Steam'
- [ ] Open 'Properties' by right-clicking on 'Microsoft Edge' in the 'Library'
- [ ] Change its name to 'Xbox Cloud Gaming (Beta)'
- [ ] Append ` --window-size=1024,640 --force-device-scale-factor=1.25 --device-scale-factor=1.25 --kiosk "https://www.xbox.com/ko-KR/play"` at the end of the command line of 'Launch Options'
- [ ] Right-click and get into 'Management' - 'Controller Layout' screen
- [ ] Search for community controller templates, apply one, and finished.

# NOTES

* Keys, shortcuts
  * Game Mode
    * Force-stop Game = Steam Button + Long Press 'B'
    * Show Software Keyboard = Steam Button + 'X'
    * Take screenshot = Steam Button + R1
    * 'Enter' = Steam Button + 'Right' D-Pad
    * 'Tab' = Steam Button + 'Down' D-Pad
    * 'ESC' = Steam Button + 'Left' D-Pad
  * Desktop Mode
    * Mouse Left-click = R2 (Right Trigger)
    * Mouse Right-click = L2 (Left Trigger)
    * Scrolling vertically/horizontally = Left Touchpad
    * Show Software Keyboard = 'X'
    * 'Enter' = 'A'
    * 'ESC' = 'B' or 'Start'
    * 'Space' = 'Y'
    * 'Tab' = 'Select'
    * 'PgUp' = Upper Right Paddle
    * 'PgDn' = Lower Right Paddle

# Troubles?

* If [barrier](https://github.com/debauchee/barrier)
  * [doesn't work on macOS due to the notarization problem](https://github.com/debauchee/barrier/issues/602), try: `xattr -rd com.apple.quarantine /Applications/Barrier.app`
  * [doesn't work on macOS due to SSL certificate errors](https://github.com/debauchee/barrier/issues/1609), try: `cd ~/Library/Application\ Support/barrier/SSL; openssl req -new -x509 -sha256 -days 9999 -nodes -out Barrier.pem -keyout Barrier.pem`

