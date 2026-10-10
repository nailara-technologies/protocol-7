#!/bin/bash
## build ik_llama.cpp llama-server + llama-bench for cpu-only inference ##
## [ a host without gpu : vps, second inference host -- todo 6WP ]      ##
##                                                                       ##
## usage : build-llama-server-cpu.sh [ <commit> ]                        ##
##   SOURCE_DIR   checkout location [ default /data/source/ik_llama.cpp ]##
##   BUILD_DIR    build dir name    [ default build-cpu ]                ##
##   JOBS         parallel jobs     [ default nproc ]                    ##
##                                                                       ##
## needs git, cmake, g++, make -- on a protocol-7 node :                 ##
##   p7c debian.install-packages cmake g++ build-essential               ##
## native build : optimized for THIS cpu [ avx2 \ fma \ avx512 as found ] ##
## -- build on the host that runs it, never copy the binary elsewhere    ##
##                                                                       ##
## measured 2026-10-11 : 8 vcpu 2 GHz avx2, fablevibes 14b-a3b q4_k_m :  ##
##   prompt 56 t/s, generation 9 t/s                                     ##

set -e

SOURCE_DIR=${SOURCE_DIR:-/data/source/ik_llama.cpp}
BUILD_DIR=${BUILD_DIR:-build-cpu}
JOBS=${JOBS:-$(nproc)}
COMMIT=${1:-}
REPO=https://github.com/ikawrakow/ik_llama.cpp.git

p7() { printf '\e[38;2;68;39;172m:: \e[38;2;6;71;195m%s\e[0m\n' "$*"; }
die() { printf '\e[38;2;197;141;7m:: %s\e[0m\n' "$*" >&2; exit 1; }

for tool in git cmake g++ make; do
    command -v "$tool" > /dev/null || die "missing $tool [ p7c debian.install-packages cmake g++ build-essential ]"
done

## checkout : clone once, then the requested commit [ or stay on head ] ##
if [ ! -d "$SOURCE_DIR/.git" ]; then
    p7 "cloning into $SOURCE_DIR"
    git clone -q "$REPO" "$SOURCE_DIR"
fi
cd "$SOURCE_DIR"
if [ -n "$COMMIT" ]; then
    git fetch -q origin
    git checkout -q "$COMMIT"
fi
p7 "source : $(git log --oneline -1)"
p7 "cpu    : $(grep -o -E 'avx2|avx512[a-z_]*|fma|f16c' /proc/cpuinfo | sort -u | tr '\n' ' ')"

## cpu-only, native, iqk kernels [ default on ], openmp ##
cmake -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_CUDA=OFF \
    -DGGML_NATIVE=ON \
    -DLLAMA_CURL=OFF > /dev/null
cmake --build "$BUILD_DIR" -j "$JOBS" --target llama-server llama-bench

p7 "built  : $SOURCE_DIR/$BUILD_DIR/bin/llama-server"
p7 "bench  : $BUILD_DIR/bin/llama-bench -m <model.gguf> -t $JOBS -p 512 -n 128"

#,,..,,..,,..,.,,,,,.,.,.,.,,,,..,.,,,.,.,...,..,,...,...,,..,.,.,,..,...,..,,
#LXX6Y24FZTOVK4U2BAG7PKA4DYD7UBAJZM4XIKHTTG6LOX7J64TVDLEPHPZ64HWPQ6LUPGF4KSJYC
#\\\|57YHEFS2NLLDZPGLRZMCXGGZUJHVGEDCP7QG2JGADDDDCRNHUTU \ / AMOS7 \ YOURUM ::
#\[7]H2LLIMLQH4FFQ4PI7PIHH7PAI5KDZWZKEBBON5LHHKBO54BA3KDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
