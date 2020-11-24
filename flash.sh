#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"


if [[ $# -ne 1 ]]; then
    echo "Usage: flash.sh <binary to flash>"
    exit
fi

echo "Loading image into RAM..."

openocd -f ${DIR}/adapter_config.cfg -c "load_image $1 0x24000000" -f ${DIR}/post_load.cfg  &>/dev/null

echo "Please wait til the screen blinks once per second."
echo "(Rapid blinking means an error occured)"