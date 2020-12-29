#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ELF=${DIR}/build/gw_base.elf
ADDRESS=0
MAGIC="0xdeadbeef"
ADAPTER=${ADAPTER:-stlink}

if [[ $# -lt 1 ]]; then
    echo "Usage: flash.sh <binary to flash> [address in flash] [size] [erase=1] [erase_blocks=0]"
    echo "Note! Destination address must be aligned to 256 bytes."
    echo "'address in flash': Where to program to. 0x000000 is the start of the flash. "
    echo "'size': Size of the binary to flash. Ideally aligned to 256 bytes."
    echo "'erase': If '0', chip erase will be skipped. Default '1'."
    echo "'erase_blocks': Number of 16KB blocks to erase, all if '0'. Default '0'."
    exit
fi

IMAGE=$1

if [[ $# -gt 1 ]]; then
    ADDRESS=$2
fi

if [[ $# -gt 2 ]]; then
    SIZE=$3
else
    SIZE=$(( 1024 * 1024 ))
fi

ERASE=1
if [[ $# -gt 3 ]]; then
    ERASE=$4
fi

ERASE_BLOCKS=0
if [[ $# -gt 4 ]]; then
    ERASE_BLOCKS=$5
fi

objdump=${OBJDUMP:-arm-none-eabi-objdump}

function get_symbol {
	name=$1
	objdump_cmd="${objdump} -t ${ELF}"
	size=$(${objdump_cmd} | grep " $name$" | cut -d " " -f1 | tr 'a-f' 'A-F' | head -n 1)
	printf "$((16#${size}))\n"
}


VAR_program_size=$(printf '0x%08x\n' $(get_symbol "program_size"))
VAR_program_address=$(printf '0x%08x\n' $(get_symbol "program_address"))
VAR_program_magic=$(printf '0x%08x\n' $(get_symbol "program_magic"))
VAR_program_done=$(printf '0x%08x\n' $(get_symbol "program_done"))
VAR_program_erase=$(printf '0x%08x\n' $(get_symbol "program_erase"))
VAR_program_erase_bytes=$(printf '0x%08x\n' $(get_symbol "program_erase_bytes"))


echo "Loading image into RAM..."
openocd -f ${DIR}/interface_${ADAPTER}.cfg \
    -c "init;" \
    -c "echo \"Resetting device\";" \
    -c "reset halt;" \
    -c "echo \"Programming ELF\";" \
    -c "load_image ${ELF};" \
    -c "sleep 100;" \
    -c "echo \"Loading image into RAM\";" \
    -c "load_image ${IMAGE} 0x24000000;" \
    -c "mww ${VAR_program_size} ${SIZE}" \
    -c "mww ${VAR_program_address} ${ADDRESS}" \
    -c "mww ${VAR_program_magic} ${MAGIC}" \
    -c "mww ${VAR_program_erase} ${ERASE}" \
    -c "mww ${VAR_program_erase_bytes} ${ERASE_BLOCKS}" \
    -c "reg sp [mrw 0x00000000];" \
    -c "reg pc [mrw 0x00000004];" \
    -c "echo \"Starting flash process\";" \
    -c "resume; exit;"

echo "Please wait til the screen blinks once per second."
echo "(Rapid blinking means an error occured)"

while true; do
    DONE_MAGIC=$(openocd -f ${DIR}/interface_${ADAPTER}.cfg -c "init; mdw ${VAR_program_done}" -c "exit;" 2>&1 | grep ${VAR_program_done} | cut -d" " -f2)
    if [[ "$DONE_MAGIC" == "cafef00d" ]]; then
        echo "Done!"
        break;
    fi
    sleep 1
done
