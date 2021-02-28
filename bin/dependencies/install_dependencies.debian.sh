#!/bin/sh

#<!> see 'install_browser_agent_dependencies.sh' for additional dependencies <!>
#         #####################################

apt-get -y install notify-osd x11-utils x11-xserver-utils unclutter xnest nxagent \
            compton openbox hsetroot xserver-xorg xserver-xephyr xvfb fuse3 \
            mpv ffmpeg melt expect mediainfo dbus-x11 libnotify-bin notify-osd \
            python3-pil python3-pygame mupdf-tools pdftk libpoppler-glib-dev \
            libio-socket-multicast-perl gnome-colors-common oxygen-icon-theme \
            liblwpx-paranoidagent-perl libnet-libdnet-perl libtimedate-perl \
            libc6-dev libimlib2-dev liblinux-inotify2-perl libimager-perl \
            libxml-rsslite-perl libtest-needsdisplay-perl libfile-slurper-perl \
            libconvert-color-perl libio-stringy-perl libdigest-crc-perl \
            libdigest-jhash-perl libfont-freetype-perl libhttp-message-perl \
            libfile-mimeinfo-perl shared-mime-info libhttp-date-perl \
            libdigest-elf-perl libyaml-libyaml-perl libbsd-resource-perl

cpanm Glib::Event
cpanm --force XML::RSS::Timing  # <-- temporary forced [ date_conv test fails ]
cpanm --force XML::RSS::TimingBot  # <-- evaluate if above module still required

# optional [i.e. not on raspbian]
apt-get -y install intel-gpu-tools firmware-misc-nonfree 2>/dev/null
# ______________________________________________________________________________
#\\M7V2FU4OYEUCQNWJEZCHY6O2GQAEHZEB6I4BBD6RGTRBKOKDOR4KTYOQKQE5MNY44L544HUOJSR62
# \\ SHIVE7LZGJV2KSVXHWKMSYDAGWMP4HAGH2PYMKZXZMPGKLJPCJDW \\// C25519-BASE-32 //
#  \\// GHVNNKSDMBIT36YUUQW2IISQUNXEBMHBV5PBOFJITVEHOCYUGBY \\ CODE SIGNATURE \\
#   ````````````````````````````````````````````````````````````````````````````
