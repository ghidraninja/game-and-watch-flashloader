#!/bin/bash

if [[ "$VERBOSE" == "1" ]]; then
    set -ex
else
    set -e
fi

TMPFILE=$(mktemp /tmp/flash_test.XXXXXX)
if [[ ! -e $TMPFILE ]]; then
    echo "Can't create tempfile!"
    exit 1
fi

sizes="1 2 3 4 5 6"
for exp in $(seq 3 24); do
    sizes="$sizes $(( 2**exp - 1 )) $(( 2**exp )) $(( 2**exp + 1 ))"
done

for size in $sizes ; do
    echo "Testing with size = $size"
    rm -f $TMPFILE
    dd if=/dev/urandom of=$TMPFILE bs=1 count=$size
    ../flash_multi.sh $TMPFILE
done
