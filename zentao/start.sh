#!/bin/bash

cd $(dirname $0)

./zbox start

if ! pgrep -f xxd; then
        cd ./run/xxd; nohup ./xxd > xxd.log 2>&1 &
fi
