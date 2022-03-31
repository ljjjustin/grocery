#!/bin/bash

docker run -d --restart=always \
    --name seafile \
    -e SEAFILE_SERVER_HOSTNAME=xxx.com \
    -e SEAFILE_ADMIN_EMAIL=xxxx@gmail.com \
    -e SEAFILE_ADMIN_PASSWORD=secretxxx \
    -v /data/seafile/data:/shared \
    -p 127.0.0.1:8090:80 \
    seafileltd/seafile:latest


