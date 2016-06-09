#!/bin/sh

export PROJ_DIR=/data/projects/nailara
export TARGET=/data/mkv/nailara.sourcecode.mkv
export BG_IMG=/data/pix/space/spacy_black.001.png

cd $PROJ_DIR

gource \
    -f \
    --date-format '< %F >  %T' \
    --git-branch master \
    -s .13 \
    -1920x1080 \
    --font-colour 0099FF \
    --background-image $BG_IMG \
    --logo $PROJ_DIR/data/gfx/nailara_logo.png \
    --auto-skip-seconds .1 \
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
    --user-scale 0.77 \
    --output-ppm-stream - \
    --output-framerate 60 -o - \
    | ffmpeg -y -r 60 -f image2pipe -vcodec ppm -i - -vcodec libx264 -preset fast -pix_fmt yuv420p -crf 1 -threads 0 -bf 0 $TARGET

#    | avconv -y -r 30 -f image2pipe -vcodec ppm -i - -b 65536K $TARGET 2>/dev/null

ls -lh $TARGET
