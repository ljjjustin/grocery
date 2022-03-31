#!/bin/bash

cp -f cloudreve.service /usr/lib/systemd/system/

systemctl daemon-reload
systemctl start cloudreve.service
systemctl enable cloudreve.service
systemctl status cloudreve.service
