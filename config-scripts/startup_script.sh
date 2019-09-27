#!/bin/bash

sudo apt update
sudo apt install -y ruby-full ruby-bundler build-essential

wget -qO - https://www.mongodb.org/static/pgp/server-3.2.asc | sudo apt-key add -
sudo bash -c 'echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse" > /etc/apt/sources.list.d/mongodb-org-3.2.list'
sudo apt update
sudo apt install -y mongodb-org
sudo systemctl start mongod
sudo systemctl enable mongod

cd /home/appuser
git clone -b monolith https://github.com/express42/reddit.git
cd reddit
bundle install
puma -d
