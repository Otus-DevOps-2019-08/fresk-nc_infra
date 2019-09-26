#!/bin/bash

set -e

cp /tmp/puma.service /etc/systemd/system/

systemctl enable puma
systemctl start puma
