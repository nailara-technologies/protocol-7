#!/bin/sh

#<!> see 'install_browser_agent_dependencies.sh' for additional dependencies <!>
#         #####################################

apt-get -y install mpv melt xvfb fuse3 pdftk xnest expect ffmpeg compton \
            nxagent openbox dbus-x11 hsetroot libc6-dev mediainfo unclutter \
            x11-utils notify-osd notify-osd mupdf-tools python3-pil \
            libgtk3-perl xserver-xorg libimlib2-dev libnotify-bin \
            libimager-perl libsoup2.4-dev python3-pygame xserver-xephyr \
            libtimedate-perl shared-mime-info libhttp-date-perl \
            oxygen-icon-theme x11-xserver-utils libdigest-crc-perl \
            libdigest-elf-perl libio-stringy-perl gnome-colors-common \
            libnet-libdnet-perl libpoppler-glib-dev libxml-rsslite-perl \
            libbsd-resource-perl libdigest-jhash-perl libfile-slurper-perl \
            libgtk3-webkit2-perl libhttp-message-perl libyaml-libyaml-perl \
            libconvert-color-perl libfile-mimeinfo-perl libsys-mmap-perl \
            libfont-freetype-perl liblinux-inotify2-perl \
            libtext-unidecode-perl libtest-needsdisplay-perl \
            liblwpx-paranoidagent-perl libio-socket-multicast-perl


cpanm IPC::Shm::Simple
cpanm Glib::Event  ##   <--   may fail on 32-bit systems [ .. check ., ]
cpanm HTTP::Soup
cpanm --force XML::RSS::Timing  # <-- temporary forced [ date_conv test fails ]
cpanm --force XML::RSS::TimingBot  # <-- evaluate if above module still required

# optional [i.e. not on raspbian]
apt-get -y install intel-gpu-tools firmware-misc-nonfree 2>/dev/null

#,,,,,,,,,..,,...,,,.,.,,,...,.,.,...,,,,,...,..,,...,...,,,,,.,,,.,.,,,.,,,,,
#KYRY6WSM2TRVOHANW2XMGUOGSXR3J4KY6AQ4JGRY2MZF26IHOWCFV2JCWMQVYWER7OEOY5ZDJ5DBY
#\\\|W5U7OIWGZYNMBWRRJZAOCGQWJBJMCJOG7CEKY3Y7NT4DMR2DGO4 \ / AMOS7 \ YOURUM ::
#\[7]FRAZIPHLULR6LJOHBVTIL7FAJUPA6H6RNV2NROXPO3MNVCNIA2CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
