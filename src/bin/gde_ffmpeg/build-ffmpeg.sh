#!/bin/bash

echo "Running FFmpeg builder ..."
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ffmpeg_source_folder="$script_dir/ffmpeg"
ffmpeg_bin_folder="$script_dir/ffmpeg-bin"

mkdir -p "$ffmpeg_bin_folder"
cd "$ffmpeg_source_folder" || exit -1
echo "Updating ffmpeg submodule ..."
git pull

./configure --prefix="$ffmpeg_bin_folder" --enable-shared --enable-gpl
make -j 6
make -j 6 install