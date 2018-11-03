#!/bin/sh

apt-get -y install notify-osd x11-utils x11-xserver-utils unclutter \
            compton openbox hsetroot xserver-xorg xserver-xephyr xvfb \
            mpv ffmpeg expect mediainfo dbus-x11 libnotify-bin notify-osd \
            python-imaging python-pygame mupdf-tools pdftk libgtk3-perl \
            libio-socket-multicast-perl gnome-colors-common oxygen-icon-theme \
            liblwpx-paranoidagent-perl libnet-libdnet-perl libtimedate-perl \
            libimlib2-dev libfile-mimeinfo-perl liblinux-inotify2-perl \
            libxml-rsslite-perl libtest-needsdisplay-perl libfile-slurper-perl \
            libconvert-color-perl libio-stringy-perl libdigest-crc-perl \
            libimager-perl libfont-freetype-perl libc6-dev

# optional [i.e. not on raspbian]
apt-get -y install intel-gpu-tools 2>/dev/null
