#!/bin/sh

#<!> see 'install_browser_agent_dependencies.sh' for additional dependencies <!>
#         #####################################

apt-get -y install notify-osd x11-utils x11-xserver-utils unclutter \
            compton openbox hsetroot xserver-xorg xserver-xephyr xvfb \
            mpv ffmpeg melt expect mediainfo dbus-x11 libnotify-bin notify-osd \
            python-pil python-pygame mupdf-tools pdftk libgtk3-perl \
            libio-socket-multicast-perl gnome-colors-common oxygen-icon-theme \
            liblwpx-paranoidagent-perl libnet-libdnet-perl libtimedate-perl \
            libc6-dev libimlib2-dev liblinux-inotify2-perl libimager-perl \
            libxml-rsslite-perl libtest-needsdisplay-perl libfile-slurper-perl \
            libconvert-color-perl libio-stringy-perl libdigest-crc-perl \
            libdigest-jhash-perl libfont-freetype-perl \
            libfile-mimeinfo-perl shared-mime-info

# optional [i.e. not on raspbian]
apt-get -y install intel-gpu-tools 2>/dev/null
