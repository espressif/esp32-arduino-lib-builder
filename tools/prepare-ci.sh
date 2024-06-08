#!/bin/bash

if [[ `get_os` == "macos" ]]; then
    # MacOS (ARM) setup
    # Change in archive-build.sh awk to gawk
    brew install gsed
    brew install gawk
    brew install gperf
    brew install ninja
    brew install ccache
    python -m pip install --upgrade pip
    pip install wheel future pyelftools
else
    sudo apt update && sudo apt install -y git wget curl libssl-dev libncurses-dev flex bison gperf python3 cmake ninja-build ccache
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && python3 get-pip.py && \
    pip3 install setuptools pyserial click future wheel cryptography pyparsing pyelftools
fi