#!/usr/bin/env bash

# bin/update_motd.rb
#
# (used: https://manytools.org/hacker-tools/convert-images-to-ascii-art/)
# 
# created on : 2012.08.21.
# last update: 2022.05.26.
# 
# by meinside@duck.com

read -r -d '' ASCII_ART <<EOF
.                            ...........
                       . .  ..#@@@@@@@@@&. .
                 #@@@@@@@@@@@@@@@@@@&&&&&&&@%..
              %###%%@@&&&&&&&&&&&&&&&&&&&&&@@@%&&
           #&####,,.,%%%%%%&&&&&&&&&&&&&&&&&@@@@@@&
         %&%##,,,, ..,%%%%%%%%&&%&&&&&&&&&&&&@@@@@@@#
         ,/,,,,,,.....,%%%%%%%%%%%%%&&&%%%&%&&@@@@@@@@..
         .,,,,,,,......,#%%%%%%%%%%%%%%%%%%%%%%@@@@@@@@&
         .,,,,,,........*###%%%%%%.           ...........
         ..,,,,..........(##(               ..       ....
.. . .... ,.,,,,.....                                 ./#
..........,,,                      ....,,,            ,##.
,,,,,..,,,,,,                     ..*&&@@@%...       (%&%#....,....,..........,.
*******,,,,,.                     ...(@@@@@#.,,**////(%%&&/,,.,.,,,,,.,,,..,,,,.
***********,*                      ...      %/....//((##%&%*,*,*,*****,,,,,,*/*/
///**/**,***,,   ..               ....       &%*.....    //*/***/////*/***//(///
*/(*******///,,  ...              ...         &&&.....,,(/(((((((((#((/(/((##((%
(/***/****/*,.,, ....            ....        ,/&&&#,./ (#((############(###%%%%%
*/***/,,,,.,     .....          ..........,*(((%&&&%,,.((#%#%%%%%%%%%%%%#%%%#&&&
/***,,,,.                      ....... ..,*/(((%%&&&&/#%%%%%%%%%&%&&&&&&&&&&&@@@
,,,,,.                         ........  *//(((#%%*(%#%&%&%&&&&&&&&&&&&@@&@#@@@@
,*,.                           ........   .        *%%#&%&&&&&&@&@@@@@@@@@@@@@@@
.                                                **%%##@&&@&&@@@@@@@@@@@@@&@@@@@
.                                   ....          *##&&@&&@@@@@@@@@@@@@@@@@@@@@@
                                      ...         .,&&&&&@@@@@@@@@@@@@@@@&@@@@@@
                                   .......       . ..& %&&@@@@@@@@@@@@@@@@@@@@@@
                                        ...     ..... (&&&@&@@@@@@@@@@@@@@@@@@@@
                                                     /&&@&@&@@@@@@@@@@@@@@@@@@@@
                                                    /&%&&&@&&@@@@@@@@@@@@@@@@@@@
                                                   (#%&&&&&&&&&&@@@@&@@@@@@@@@@@
EOF

if [ -f /etc/motd ]; then
	sudo bash -c "cat << EOF > /etc/motd
$ASCII_ART
EOF" && \
		echo "updated: /etc/motd"
elif [ -d /etc/update-motd.d/ ]; then
	sudo bash -c "cat << EOF > /etc/update-motd.d/09-ascii-art
#!/bin/sh
#
# created/updated by ~/bin/update_motd.sh

cat << ASCII_ART
$ASCII_ART
ASCII_ART
EOF" && \
		sudo chown root.root /etc/update-motd.d/09-ascii-art && \
		sudo chmod +x /etc/update-motd.d/09-ascii-art && \
		echo "updated: /etc/update-motd.d/09-ascii-art"

fi

