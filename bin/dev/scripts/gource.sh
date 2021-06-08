#!/bin/sh

export PROJ_DIR=/data/projects/nailara
export TARGET=/data/mkv/nailara.sourcecode.mkv
export BG_IMG=/data/pix/space/spacy_black.001.png

cd $PROJ_DIR

gource \
    -f \
    --date-format '< %F >  %T' \
    --git-branch master \
    -s .33333 \
    -1920x1080 \
    --font-colour 00AAFF \
    --background-image $BG_IMG \
    --logo $PROJ_DIR/data/gfx/nailara_logo.png \
    --auto-skip-seconds 0.00001 \
    --multi-sampling \
    --stop-at-end \
    --highlight-users \
    --hide mouse,progress \
    --file-idle-time 0 \
    --max-files 0  \
    --background-colour 000000 \
    --font-size 17 \
    --caption-size 27 \
    --caption-duration 1.2 \
    --user-scale 0.69 \
    --output-ppm-stream - \
    --output-framerate 60 -o - \
    | ffmpeg -y -r 60 -f image2pipe -vcodec ppm -i - -vcodec libx264 -preset ultrafast -pix_fmt yuv420p -crf 1 -threads 0 -bf 0 $TARGET

# current settings [using 'slow'] -> ~5:13 min / 6.6 GB

#    | avconv -y -r 30 -f image2pipe -vcodec ppm -i - -b 65536K $TARGET 2>/dev/null

ls -lh $TARGET

#,...,...,..,,...,.,.,,,,,,.,,,,,,,.,,.,.,,.,,,.,,.,,,.,.,,,.,,,,,..,,,..,.,.,
#2SWFTX4PZUARLXK4ZPLWHZ4NX7C5YVE7H3E6Q64ITYOBZDOHGIM2AVEH4E4GGI7NC7PYILESUQ24I
#\\\|YVP2IZUV2ZSZIOGPPZSIY45ZKOAV4RWBI7SL3WVMCLRNNNTKRWP \ / AMOS7 \ YOURUM ::
#\[7]CJFBWAV35QF6PPOOTNBNPZRUWJD4TD55OUE36HNHXSQSA77YSIAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
