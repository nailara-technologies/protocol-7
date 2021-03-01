#!/bin/sh

#<!> see 'install_browser_agent_dependencies.sh' for additional dependencies <!>
#         #####################################

apt-get -y install mpv melt xvfb fuse3 pdftk xnest expect ffmpeg compton \
           nxagent openbox dbus-x11 hsetroot libc6-dev mediainfo unclutter \
           x11-utils notify-osd notify-osd mupdf-tools python3-pil \
           libgtk3-perl xserver-xorg libimlib2-dev libnotify-bin \
           libimager-perl python3-pygame xserver-xephyr libtimedate-perl \
           shared-mime-info libhttp-date-perl oxygen-icon-theme \
           x11-xserver-utils libdigest-crc-perl libdigest-elf-perl \
           libio-stringy-perl gnome-colors-common libnet-libdnet-perl \
           libpoppler-glib-dev libxml-rsslite-perl libbsd-resource-perl \
           libdigest-jhash-perl libfile-slurper-perl libgtk3-webkit2-perl \
           libhttp-message-perl libyaml-libyaml-perl libconvert-color-perl \
           libfile-mimeinfo-perl libfont-freetype-perl \
           liblinux-inotify2-perl libtest-needsdisplay-perl \
           liblwpx-paranoidagent-perl libio-socket-multicast-perl

cpanm Glib::Event
cpanm --force XML::RSS::Timing  # <-- temporary forced [ date_conv test fails ]
cpanm --force XML::RSS::TimingBot  # <-- evaluate if above module still required

# optional [i.e. not on raspbian]
apt-get -y install intel-gpu-tools firmware-misc-nonfree 2>/dev/null

# ______________________________________________________________________________
#\\WX63FBARSQJ3AGHR5G5IZC4EXMLWMXG2DE2DC57Y5Q2CONU5SCMZSWK4N2QRWSZ33EIFXY3MLK7X2
# \\ Y7LDYDNGLA6VTX5HDJP33DNKT74ZOQW4IZ5B5S4GXXEF5P2HG7MD \\// C25519-BASE-32 //
#  \\// 3TOOEAKFYSIPD7NEMBK72C2C5XVDQNBILXUTAEBL4MXOB5PMUBY \\ CODE SIGNATURE \\
#   ````````````````````````````````````````````````````````````````````````````
