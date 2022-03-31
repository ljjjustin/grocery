#!/bin/bash

if [ ! -e /usr/lib/systemd/system/clash.service ]; then
    cp clash.service /usr/lib/systemd/system/
    systemctl daemon-reload
fi

systemctl start clash.service
systemctl status clash.service
