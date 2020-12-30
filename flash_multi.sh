#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ELF=${DIR}/build/gw_base.elf

if [[ $# -lt 1 ]]; then
    echo "Usage: flash_multi.sh <binary to flash>"
    echo "Note! This will cut the binary in 1M chunks and flash them to 0x000000 and onwards"
    exit
fi

IMAGE=$1

if [[ $# -gt 1 ]]; then
    ADDRESS=$2
fi

if [[ $# -gt 2 ]]; then
    SIZE=$3
fi

# stat on macOS has different flags
if [[ "$(uname -s)" == "Darwin" ]]; then
    FILESIZE=$(stat -f%z $IMAGE)
else 
    FILESIZE=$(stat -c%s $IMAGE)
fi

CHUNKS=$(( FILESIZE / (1024*1024) ))
SIZE=$((FILESIZE))
SECTOR_SIZE=$(( 4 * 1024 ))
ERASE_BYTES=0

echo $CHUNKS

ERASE=1
i=0
while [[ $SIZE -gt 0 ]]; do
    ADDRESS_HEX=$(printf "0x%08x" $(( i * 1024 * 1024 ))) 
    if [[ $SIZE -gt $((1024*1024)) ]]; then
        CHUNK_SIZE=$((1024*1024))
    else
        CHUNK_SIZE=${SIZE}
    fi
    SIZE_HEX=$(printf "0x%08x" ${CHUNK_SIZE})

    TMPFILE=$(mktemp /tmp/flash_chunk.XXXXXX)
    if [[ ! -e $TMPFILE ]]; then
        echo "Can't create tempfile!"
        exit 1
    fi

    echo "Preparing chunk $i in file ${TMPFILE}"
    dd if=${IMAGE} of=${TMPFILE} bs=1024 count=$(( (CHUNK_SIZE + 1023) / 1024 )) skip=$(( i * 1024 ))

    if [[ $CHUNK_SIZE -le 8 ]]; then
        echo "Chunk size <= 8 bytes, padding with zeros"
        dd if=/dev/zero of=${TMPFILE} bs=1 count=$(( 9 - CHUNK_SIZE )) seek=${CHUNK_SIZE}
    fi
    
    echo "Flashing!"
    if [[ $ERASE -eq 1 ]]; then
        ERASE_BYTES=$(( (( SIZE + SECTOR_SIZE - 1 ) / SECTOR_SIZE) * SECTOR_SIZE ))
        echo "erasing $ERASE_BYTES"
        echo ${DIR}/flash.sh ${TMPFILE} ${ADDRESS_HEX} ${SIZE_HEX} ${ERASE} ${ERASE_BYTES}
        ${DIR}/flash.sh ${TMPFILE} ${ADDRESS_HEX} ${SIZE_HEX} ${ERASE} ${ERASE_BYTES}
    else
        ${DIR}/flash.sh ${TMPFILE} ${ADDRESS_HEX} ${SIZE_HEX} 0
    fi

    # Skip erase the following iterations
    ERASE=0

    rm -f ${TMPFILE}

    SIZE=$(( SIZE - 1024*1024 ))
    i=$(( i + 1 ))
done

