#!/bin/bash

cd $(dirname $0)

# wait for the network and other apps to start
[[ " $@ " =~ " --no-sleep " ]] || sleep 10;

while true; do
    conky -c miracle-config.lua >> /tmp/conky.log 2>&1
done

