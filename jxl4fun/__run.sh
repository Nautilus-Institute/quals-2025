#!/bin/bash

cd $(dirname $0)

echo "flug{placeholder_flag1_____its_pretty_long:$(head -c 45 /dev/urandom | xxd -p -c0)}" > flag1

echo "flug{placeholder_flag2_____its_pretty_long:$(head -c 45 /dev/urandom | xxd -p -c0)}" > flag2

# Random location for second flag
flag_path="/flag_$(head -c 19 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9')"

docker run -v $(pwd)/flag1:/flag_intro -v $(pwd)/flag2:$flag_path --rm -i jxl4fun /libjxl/bin/run_challenge.sh