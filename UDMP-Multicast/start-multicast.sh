#!/bin/sh

## Start PodMan with the multi-cast realy container
podman run -d --restart=always --network=host -e OPTS="--noMDNS" -e INTERFACES="br0 br107" docker.io/scyto/multicast-relay
