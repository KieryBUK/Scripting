#!/bin/sh
podman run -d --restart=always --network=host -e OPTS="--noMDNS" -e INTERFACES="br0 br107" /mnt/data/on_boot.d/multicast-relay
