#!/bin/bash

cd $(dirname $0)

if pgrep -f xxd; then
    pkill -9 -f xxd
fi

./zbox stop
