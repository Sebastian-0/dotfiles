#!/bin/bash
set -euo pipefail

sudo apt-get install git python3-apt python3-debian pandoc -y

git clone https://gitlab.com/volian/nala.git
cd nala
sudo make install
cd -
sudo rm -rf nala

sudo ln -s /usr/local/bin/nala /usr/bin/nala
