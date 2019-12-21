#!/bin/bash

TMP=`mktemp -d`

echo -e "\n\n :: Installing dependencies..\n\n"

apt-get -y install git libsdl2-dev libsdl2-mixer-dev libsdl2-ttf-dev

echo -e "\n\n :: Downloading game source code..\n\n"

cd $TMP

git clone git://github.com/anotherlink/pong-game.git

echo -e "\n\n :: Preparing game binary..\n\n"

cd pong-game

make

echo -e "\n\n :: Installing..\n\n"

cp -v pong /usr/local/bin/pong-game

mkdir /usr/local/share/pong-game
cp -av resources /usr/local/share/pong-game/

rm -rf $TMP/pong-game
rmdir $TMP

echo -e "\n\n :: Done.\n\n"
