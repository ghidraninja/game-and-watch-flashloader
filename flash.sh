#!/bin/bash

if [[ "$VERBOSE" == "1" ]]; then
    set -ex
else
    set -e
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ELF=${DIR}/build/gw_base.elf
ADDRESS=0
MAGIC="0xdeadbeef"

OPENOCD=${OPENOCD:-$(which openocd || true)}
if [[ -z "${OPENOCD}" ]]; then
  echo "Cannot find 'openocd' in the PATH. You can set the environment variable 'OPENOCD' to manually specify the location"
  exit 2
fi

# $1: file to hash
# $2: file to write hash to in hex
function calc_sha256sum() {
    SHA256SUM=${SHA256SUM:-$(which sha256sum || true)}
    OPENSSL=${OPENSSL:-$(which openssl || true)}

    if [[ ! -z "${SHA256SUM}" ]]; then
        ${SHA256SUM} "$1" | cut -d " " -f1 > "$2"
    elif [[ ! -z "${OPENSSL}" ]]; then
        ${OPENSSL} sha256 "$1" | cut -d " " -f2 > "$2"
    else
        echo "Cannot find 'sha256sum' or 'openssl' in the PATH. You can set the environment variables 'SHA256SUM' or 'OPENSSL' to manually specify the location to either tool. Only one of the tools are needed."
        exit 2
    fi
}

ADAPTER=${ADAPTER:-stlink}

if [[ $# -lt 1 ]]; then
    echo "Usage: flash.sh <binary to flash> [address in flash] [size] [erase=1] [erase_bytes=0]"
    echo "Note! Destination address must be aligned to 256 bytes."
    echo "'address in flash': Where to program to. 0x000000 is the start of the flash. "
    echo "'size': Size of the binary to flash. Ideally aligned to 256 bytes."
    echo "'erase': If '0', chip erase will be skipped. Default '1'."
    echo "'erase_bytes': Number of bytes to erase, all if '0'. Default '0'."
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

ERASE_BYTES=0
if [[ $# -gt 4 ]]; then
    ERASE_BYTES=$5
fi

HASH_HEX_FILE=$(mktemp /tmp/sha256_hash_hex.XXXXXX)
if [[ ! -e "${HASH_HEX_FILE}" ]]; then
    echo "Can't create tempfile!"
    exit 1
fi

HASH_FILE=$(mktemp /tmp/sha256_hash.XXXXXX)
if [[ ! -e "${HASH_FILE}" ]]; then
    echo "Can't create tempfile!"
    exit 1
fi
dd if="${IMAGE}" of="${HASH_FILE}" bs=1 count=$(( SIZE )) 2> /dev/null
calc_sha256sum "${HASH_FILE}" "${HASH_HEX_FILE}"
rm -f "${HASH_FILE}"

if [[ "${GCC_PATH}" != "" ]]; then
	DEFAULT_OBJDUMP=${GCC_PATH}/arm-none-eabi-objdump
else
	DEFAULT_OBJDUMP=arm-none-eabi-objdump
fi

OBJDUMP=${OBJDUMP:-$DEFAULT_OBJDUMP}

function get_symbol {
	name=$1
	objdump_cmd="${OBJDUMP} -t ${ELF}"
	size=$(${objdump_cmd} | grep " $name$" | cut -d " " -f1 | tr 'a-f' 'A-F' | head -n 1)
	printf "$((16#${size}))\n"
}


VAR_program_size=$(printf '0x%08x\n' $(get_symbol "program_size"))
VAR_program_address=$(printf '0x%08x\n' $(get_symbol "program_address"))
VAR_program_magic=$(printf '0x%08x\n' $(get_symbol "program_magic"))
VAR_program_done=$(printf '0x%08x\n' $(get_symbol "program_done"))
VAR_program_erase=$(printf '0x%08x\n' $(get_symbol "program_erase"))
VAR_program_erase_bytes=$(printf '0x%08x\n' $(get_symbol "program_erase_bytes"))
VAR_program_expected_sha256=$(printf '0x%08x\n' $(get_symbol "program_expected_sha256"))


echo "Loading image into RAM..."
${OPENOCD} -f ${DIR}/interface_${ADAPTER}.cfg \
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
    -c "mww ${VAR_program_erase_bytes} ${ERASE_BYTES}" \
    -c "load_image ${HASH_HEX_FILE} ${VAR_program_expected_sha256};" \
    -c "reg sp [mrw 0x00000000];" \
    -c "reg pc [mrw 0x00000004];" \
    -c "echo \"Starting flash process\";" \
    -c "resume; exit;"

# Remove the temporary hash files
rm -f "${HASH_HEX_FILE}"

echo "Please wait til the screen blinks once per second."
echo "(Rapid blinking means an error occured)"

while true; do
    DONE_MAGIC=$(${OPENOCD} -f ${DIR}/interface_${ADAPTER}.cfg -c "init; mdw ${VAR_program_done}" -c "exit;" 2>&1 | grep ${VAR_program_done} | cut -d" " -f2)
    if [[ "$DONE_MAGIC" == "cafef00d" ]]; then
        echo "Done!"
        break;
    elif [[ "$DONE_MAGIC" == "badcafee" ]]; then
        echo "Hash mismatch in RAM. Flashing failed."
        exit 3;
    elif [[ "$DONE_MAGIC" == "badf000d" ]]; then
        echo "Hash mismatch in FLASH. Flashing failed."
        exit 3;
    fi
    sleep 1
done
