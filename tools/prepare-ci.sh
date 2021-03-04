#!/bin/bash

sudo apt-get install -y git wget curl libssl-dev libncurses-dev flex bison gperf python python-setuptools python-cryptography python-pyparsing python-pyelftools cmake ninja-build ccache
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && python get-pip.py && \
pip3 install pyserial click future wheel
