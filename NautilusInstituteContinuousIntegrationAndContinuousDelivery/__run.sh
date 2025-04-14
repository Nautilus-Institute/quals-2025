#!/bin/bash

cd $(dirname $0)

echo "flug{placeholder_flag1_____its_pretty_long:$(head -c 45 /dev/urandom | xxd -p -c0)}" > flag1

echo "flug{placeholder_flag2_____its_pretty_long:$(head -c 45 /dev/urandom | xxd -p -c0)}" > flag2

docker run -v $(pwd)/flag1:/flag1 -v $(pwd)/flag2:/flag2 --rm -i nicicd /nicicd/run_challenge.sh