#!/bin/bash

cd $(dirname $0)

# wait for the network and other apps to start
[[ " $@ " =~ " --no-sleep " ]] || sleep 10;

[[ -f miracle-config.lua ]] || cp miracle-config.example.lua miracle-config.lua
while true; do
    conky -c miracle-config.lua >> /tmp/conky.log 2>&1
done
