#!/bin/sh

export TARGET=/data/mkv/protocol-7-source-dev.mkv

export START=2019-05-11

##  export START=2012-06-05  ##  git import date


export BRANCH=base

export FRAMERATE=30
export RESOLUTION=1491x839

export SCRIPT_PATH=$0;
export PROJ_DIR=`realpath $SCRIPT_PATH | sed 's|bin/dev/scripts/gource.sh$||'`

export FONT=$PROJ_DIR/data/ttf/console/white-rabbit.flipped.ttf
export BG_IMG=/data/pix/space/spacy_black.001.png
export FONTCOLOR="0647C3"

export THREADS=`$PROJ_DIR/bin/cpu-threads`

cd $PROJ_DIR

gource \
    -f \
    --disable-input \
    --date-format '< %F >  %T' \
    --git-branch $BRANCH \
    --start-date $START \
    -s .33333 \
    -$RESOLUTION \
    --padding 1.42 \
    --camera-mode overview \
    --font-colour $FONTCOLOR \
    --background-image $BG_IMG \
    --logo $PROJ_DIR/data/gfx/logos/nailara.png \
    --auto-skip-seconds 0.00001 \
    --multi-sampling \
    --stop-at-end \
    --highlight-users \
    --hide mouse,progress \
    --file-idle-time 0 \
    --max-files 0  \
    --background-colour 000000 \
    --font-file $FONT \
    --font-size 17 \
    --caption-size 27 \
    --caption-duration 1.2 \
    --user-scale 0.69 \
    --output-ppm-stream - \
    --output-framerate $FRAMERATE -o - \
    | ffmpeg -y -r $FRAMERATE -f image2pipe -vcodec ppm -i - -vcodec libx264 -preset ultrafast -pix_fmt yuv420p -crf 1 -threads $THREADS -bf 0 $TARGET

#    | avconv -y -r 30 -f image2pipe -vcodec ppm -i - -b 65536K $TARGET 2>/dev/null

ls -lh $TARGET

#,,,.,,,.,.,.,,,.,,..,.,.,,..,,,,,,..,,.,,,,.,..,,...,...,..,,..,,.,,,,..,...,
#6KUZTSPCGL7DK4UGVVTZ4RTBBHMQCAQU3T4QVV7H7OYNABS4KEQXF47XHAKAS5UPNLQZP5FBPHTDU
#\\\|LRQOFYBUZQ62RIGJ5O4K4EKJSIYPUEW3YVBQYHIBPRW7GKFRB3D \ / AMOS7 \ YOURUM ::
#\[7]TS2L6PGQXPV2EVZSTB7WGXFSKW5YJQOIE7YJFNYWTU5MUPB7LEDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
