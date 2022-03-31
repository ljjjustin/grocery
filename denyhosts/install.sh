#!/bin/bash

yum install -y python-pip
pip install ipaddr
python setup.py install

cp -f denyhosts.conf /etc/
cp -f denyhosts.service /usr/lib/systemd/system/

systemctl daemon-reload
systemctl enable denyhosts.service
systemctl start denyhosts.service

./daemon-control-dist status
